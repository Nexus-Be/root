#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generate_all_docs.py
Tự động phân tích docs/excel/flow_mock_excel.md và sinh toàn bộ hồ sơ tài liệu API độc lập
vào docs/api/B_none/{Service}/ với chuẩn 100% số nhiều, Code Trace 4 tầng, Error Matrix RFC 9110,
và đặc tả rõ ràng Enums kèm tên trường JSON Payload và hướng dẫn Frontend.
"""

import os
import re
import json

from scaffold_api_docs import (
    SERVICES, BASE_DIR, ENUM_SPECS, generate_enum_section,
    standardize_endpoint, get_rbac, get_idempotency
)

with open('docs/excel/flow_mock_excel.md', 'r', encoding='utf-8') as f:
    raw_content = f.read()

# Chunk by '### ['
chunks = re.split(r'\n(?=###\s+\[)', raw_content)[1:]
print(f"Tổng số chunks từ flow_mock_excel.md: {len(chunks)}")

def parse_chunk(chunk):
    lines = chunk.strip().split('\n')
    header_m = re.match(r'###\s+\[(.*?)\]\s+(GET|POST|PUT|PATCH|DELETE|JOB|GRPC)\s+([^\n]+)', lines[0])
    if not header_m:
        return None
    ep_id = header_m.group(1).strip()
    method = header_m.group(2).strip()
    path = header_m.group(3).strip()
    
    desc_m = re.search(r'-\s+\*\*Mô tả:\*\*\s*(.+)', chunk)
    desc = desc_m.group(1).strip() if desc_m else 'Mô tả nghiệp vụ API'
    
    ref_m = re.search(r'-\s+\*\*ID Tham Chiếu:\*\*\s*(.+)', chunk)
    ref_id = ref_m.group(1).strip() if ref_m else ep_id
    
    req_body_m = re.search(r'#### Request.*?(?:```[a-zA-Z0-9_-]*\n(.*?)\n```)', chunk, re.DOTALL)
    req_body = req_body_m.group(1).strip() if req_body_m else ''
    
    res_m = re.search(r'#### Response.*?(?:```[a-zA-Z0-9_-]*\n(.*?)\n```)', chunk, re.DOTALL)
    res_body = res_m.group(1).strip() if res_m else ''
    
    err_m = re.search(r'#### Error Responses.*?(?:```[a-zA-Z0-9_-]*\n(.*?)\n```)', chunk, re.DOTALL)
    err_body = err_m.group(1).strip() if err_m else ''
    
    return {
        'id': ep_id,
        'method': method,
        'path': path,
        'desc': desc,
        'ref_id': ref_id,
        'req': req_body,
        'res': res_body,
        'err': err_body
    }

parsed_endpoints = []
for c in chunks:
    p = parse_chunk(c)
    if p:
        parsed_endpoints.append(p)

print(f"Số lượng endpoints parse thành công: {len(parsed_endpoints)}")

def slugify(text):
    s = text.upper()
    s = re.sub(r'[^A-Z0-9]+', '_', s)
    return s.strip('_')

def determine_service_and_trace(ep):
    p = ep['path']
    method = ep['method']
    ep_id = ep['id']
    
    # Defaults
    service = 'User'
    feature = 'User'
    gateway_route = 'user-route'
    controller = 'UsersController'
    action = 'GetUsers'
    service_iface = 'IUserService'
    service_impl = 'UserService'
    entity = 'User'
    table = 'Users'
    enums = []

    # 1. User Service
    if ep_id.isdigit() and int(ep_id) <= 10:
        service = 'User'
        feature = 'Auth'
        gateway_route = 'auth-route'
        controller = 'AuthController'
        service_iface = 'IAuthService'
        service_impl = 'AuthService'
        entity = 'User'
        table = 'Users'
        action_map = {
            '1': ('Register', ['UserStatus']),
            '2': ('VerifyOtp', ['UserStatus']),
            '3': ('ResendOtp', []),
            '4': ('Login', ['UserStatus']),
            '5': ('Refresh', []),
            '6': ('ForgotPassword', []),
            '7': ('ResetPassword', []),
            '8': ('ChangePassword', []),
            '9': ('Logout', []),
            '10': ('LogoutAll', [])
        }
        if ep_id in action_map:
            action, enums = action_map[ep_id]

    elif ep_id in ['11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', 'Row 93', 'Row 95']:
        service = 'User'
        feature = 'Users'
        gateway_route = 'user-me-route' if '/me' in p else ('users-plural-route' if '/users' in p or '/user' in p else 'reviews-route')
        controller = 'UsersController'
        service_iface = 'IUserService'
        service_impl = 'UserService'
        entity = 'User'
        table = 'Users'
        if ep_id in ['11', '12']:
            action = 'GetSessions' if method == 'GET' else 'RevokeSession'
            entity, table = 'UserSession', 'UserSessions'
        elif ep_id in ['13', '14']:
            action = 'GetMe' if method == 'GET' else 'UpdateMe'
            enums = ['UserStatus', 'Gender']
        elif ep_id in ['15', '16']:
            action = 'GetMeAvatar' if method == 'GET' else 'UploadMeAvatar'
        elif ep_id in ['17', '18']:
            action = 'GetMeReputation' if ep_id == '17' else 'GetMePenalties'
            entity, table = ('ReputationScore', 'ReputationScores') if ep_id == '17' else ('UserPenalty', 'UserPenalties')
            enums = ['TrustLevel'] if ep_id == '17' else ['PenaltyStatus', 'PenaltyType']
        elif ep_id in ['19', '20']:
            action = 'GetUserProfile' if ep_id == '19' else 'GetUserAvatar'
            enums = ['UserStatus', 'Gender']
        elif ep_id == '21':
            action = 'GetSellerInfo'
            gateway_route = 'sellers-plural-route'
            enums = ['SellerProfileStatus']
        elif ep_id in ['22', '23']:
            action = 'GetUserReputation' if ep_id == '22' else 'GetUserReputationHistory'
            entity, table = 'ReputationScore', 'ReputationScores'
            enums = ['TrustLevel'] if ep_id == '22' else ['ReputationChangeReason']
        elif ep_id in ['24', '25', '26', 'Row 93', 'Row 95']:
            action = 'GetUserReviews' if ep_id == '24' else ('UploadReviewFiles' if ep_id == '25' else 'CreateReview')
            entity, table = 'UserReview', 'UserReviews'
            enums = ['ReviewerRole']
        elif ep_id in ['27', '28', '29']:
            action = 'UploadReportFiles' if ep_id == '27' else ('CreateReport' if ep_id == '28' else 'GetMeReports')
            entity, table = 'UserReport', 'UserReports'
            enums = ['ReportStatus', 'ReportViolationType']

    elif ep_id in ['30', '31', '32', '33', '34', '35', '36']:
        service = 'User'
        feature = 'Seller'
        gateway_route = 'sellers-plural-route'
        controller = 'SellerController'
        service_iface = 'ISellerService'
        service_impl = 'SellerService'
        entity = 'SellerProfile'
        table = 'SellerProfiles'
        action_map = {
            '30': ('RegisterSeller', ['SellerProfileStatus']),
            '31': ('ResendSellerOtp', []),
            '32': ('UploadSellerDocuments', []),
            '33': ('VerifySellerOtp', ['SellerProfileStatus']),
            '34': ('GetRegistrationStatus', ['SellerProfileStatus']),
            '35': ('GetSellerProfile', ['SellerProfileStatus']),
            '36': ('UpdateSellerProfile', ['SellerProfileStatus'])
        }
        if ep_id in action_map:
            action, enums = action_map[ep_id]

    elif ep_id in ['37', '37B', '38', '39', '40', '41', '41B', '42', '43', '44', '45', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58']:
        service = 'User'
        feature = 'AdminUsers'
        gateway_route = 'admin-users-plural-route' if '/users' in p or '/user' in p else 'admin-user-route'
        controller = 'AdminUsersController'
        service_iface = 'IAdminUserService'
        service_impl = 'AdminUserService'
        entity = 'User'
        table = 'Users'
        if ep_id in ['37', '37B', '38', '39']:
            action = 'GetSellerRegistrations' if ep_id == '37' else ('GetSellerRegistrationDetail' if ep_id == '37B' else ('ApproveSellerRegistration' if ep_id == '38' else 'RejectSellerRegistration'))
            entity, table = 'SellerRegistration', 'SellerRegistrations'
            enums = ['SellerProfileStatus']
        elif ep_id in ['40', '41', '41B']:
            action = 'GetReports' if ep_id == '40' else ('ResolveReport' if ep_id == '41' else 'DismissReport')
            entity, table = 'UserReport', 'UserReports'
            enums = ['ReportStatus', 'ReportViolationType']
        elif ep_id == '42':
            action = 'HideReview'
            entity, table = 'UserReview', 'UserReviews'
            enums = ['ReviewerRole']
        elif ep_id in ['43', '44', '45', '46', '47', '48', '49']:
            action = 'GetUsers' if ep_id == '43' else ('CreateUser' if ep_id == '44' else ('GetUserDetail' if ep_id == '45' else ('UpdateUser' if ep_id == '46' else ('DeleteUser' if ep_id == '47' else ('BanUser' if ep_id == '48' else 'UnbanUser')))))
            enums = ['UserStatus', 'Gender', 'RoleType']
        elif ep_id == '50':
            action = 'GetSellerDetail'
            entity, table = 'SellerProfile', 'SellerProfiles'
            enums = ['SellerProfileStatus']
        elif ep_id == '51':
            action = 'AssignRoles'
            enums = ['RoleType']
        elif ep_id == '52':
            action = 'AdjustReputation'
            enums = ['ReputationChangeReason', 'TrustLevel']
        elif ep_id in ['53', '54', '55']:
            action = 'GetRoles' if ep_id == '53' else ('GetPermissions' if ep_id == '54' else 'UpdateRolePermissions')
            entity, table = 'Role', 'Roles'
            enums = ['RoleType']
        elif ep_id == '56':
            action = 'GetAuditLogs'
            entity, table = 'AuditLog', 'AuditLogs'
        elif ep_id in ['57', '58']:
            action = 'GetConfigs' if ep_id == '57' else 'UpdateConfigs'
            entity, table = 'SystemConfig', 'SystemConfigs'

    # 2. Catalog Service
    elif any(x in p for x in ['/categories', '/products', '/variant', '/variants']) and not any(y in p for y in ['stock-in']):
        service = 'Catalog'
        feature = 'Categories' if '/categories' in p else 'Products'
        gateway_route = 'catalog-categories-route' if '/categories' in p else ('catalog-variants-route' if '/variant' in p else 'catalog-products-route')
        controller = 'CategoriesController' if '/categories' in p else 'ProductsController'
        service_iface = 'ICategoryService' if '/categories' in p else 'IProductService'
        service_impl = 'CategoryService' if '/categories' in p else 'ProductService'
        entity = 'Category' if '/categories' in p else ('ProductVariant' if '/variant' in p else 'Product')
        table = 'Categories' if '/categories' in p else ('ProductVariants' if '/variant' in p else 'Products')
        if '/categories' in p:
            action = 'GetCategories' if method == 'GET' and '{categoryId}' not in p else ('GetCategoryById' if method == 'GET' else ('CreateCategory' if method == 'POST' else ('UpdateCategory' if method == 'PUT' else 'DeleteCategory')))
        else:
            action = 'GetProducts' if method == 'GET' and '{productId}' not in p else ('GetProductById' if method == 'GET' else ('CreateProduct' if method == 'POST' else ('UpdateProduct' if method in ['PUT', 'PATCH'] else 'DeleteProduct')))
            enums = ['ProductStatus']
            if '/variant' in p:
                enums = ['VariantStatus']

    # 3. Commerce Service
    elif any(x in p for x in ['/cart', '/checkout', '/orders', '/order/', '/subOrder']):
        service = 'Commerce'
        feature = 'Carts' if '/cart' in p else 'Orders'
        gateway_route = 'commerce-carts-route' if '/cart' in p else ('commerce-checkouts-route' if '/checkout' in p else ('commerce-sub-orders-route' if '/subOrder' in p else 'commerce-orders-route'))
        controller = 'CartsController' if '/cart' in p else 'OrdersController'
        service_iface = 'ICartService' if '/cart' in p else 'IOrderService'
        service_impl = 'CartService' if '/cart' in p else 'OrderService'
        entity = 'Cart' if '/cart' in p else ('SubOrder' if '/subOrder' in p else 'Order')
        table = 'Carts' if '/cart' in p else ('SubOrders' if '/subOrder' in p else 'Orders')
        if '/cart' in p:
            action = 'GetCart' if method == 'GET' and 'select' not in p else ('SelectCartItems' if 'select' in p else ('AddCartItem' if method == 'POST' else ('UpdateCartItem' if method == 'PATCH' else 'RemoveCartItem')))
            enums = ['CartStatus']
        elif '/checkout' in p:
            action = 'QuoteCheckout'
            enums = ['PaymentMethod']
        else:
            action = 'GetOrders' if method == 'GET' and '{orderId}' not in p and '{subOrderId}' not in p else ('GetOrderDetail' if '{orderId}' in p and method == 'GET' else ('GetSubOrderDetail' if '{subOrderId}' in p and method == 'GET' else ('CreateOrder' if method == 'POST' and 'cancel' not in p and 'accept' not in p and 'reject' not in p and 'refund' not in p else ('CancelOrder' if 'cancel' in p else ('AcceptOrder' if 'accept' in p else ('RejectOrder' if 'reject' in p else 'RefundSubOrder'))))))
            enums = ['OrderStatus', 'SubOrderStatus', 'PaymentMethod']

    # 4. Auction Service
    elif '/auction' in p or '/bids' in p or 'Auction.' in p:
        service = 'Auction'
        feature = 'Auctions' if '/auction' in p or 'Auction.' in p else 'Bids'
        gateway_route = 'admin-auctions-route' if '/admin/auctions' in p else ('admin-auction-configs-route' if 'auction-configs' in p else ('auction-bids-route' if '/bids' in p else 'auction-auctions-route'))
        controller = 'AuctionsController' if feature == 'Auctions' else 'BidsController'
        service_iface = 'IAuctionService' if feature == 'Auctions' else 'IBidService'
        service_impl = 'AuctionService' if feature == 'Auctions' else 'BidService'
        entity = 'Auction' if feature == 'Auctions' else 'Bid'
        table = 'Auctions' if feature == 'Auctions' else 'Bids'
        enums = ['AuctionStatus']
        if '/bids' in p:
            action = 'PlaceBid' if method == 'POST' else 'GetAuctionBids'
        else:
            action = 'GetAuctions' if method == 'GET' and '{auctionId}' not in p else ('GetAuctionById' if method == 'GET' else ('CreateAuction' if method == 'POST' else 'UpdateAuction'))

    # 5. Fulfillment Service
    elif '/shipment' in p or '/inventory' in p or 'stock-in' in p:
        service = 'Fulfillment'
        feature = 'Shipments' if '/shipment' in p else 'Warehouses'
        gateway_route = 'fulfillment-shipments-route' if '/shipment' in p else 'fulfillment-inventories-route'
        controller = 'ShipmentsController' if feature == 'Shipments' else 'WarehousesController'
        service_iface = 'IShipmentService' if feature == 'Shipments' else 'IWarehouseService'
        service_impl = 'ShipmentService' if feature == 'Shipments' else 'WarehouseService'
        entity = 'Shipment' if feature == 'Shipments' else 'InventoryItem'
        table = 'Shipments' if feature == 'Shipments' else 'InventoryItems'
        enums = ['ShipmentStatus']
        if feature == 'Shipments':
            action = 'GetShipmentById' if method == 'GET' and '{shipmentId}' in p else ('GetSellerShipments' if method == 'GET' else ('UpdateTracking' if method == 'PATCH' else ('CompleteShipment' if 'complete' in p else 'Webhook')))
        else:
            action = 'StockIn'

    # 6. Wallet Service
    elif '/wallet' in p or '/payments' in p:
        service = 'Wallet'
        feature = 'Wallets'
        gateway_route = 'admin-wallets-route' if '/admin/' in p else 'wallet-wallets-route'
        controller = 'AdminWalletsController' if '/admin/' in p else 'WalletsController'
        service_iface = 'IAdminWalletService' if '/admin/' in p else 'IWalletService'
        service_impl = 'AdminWalletService' if '/admin/' in p else 'WalletService'
        entity = 'WalletWithdrawal' if 'withdrawals' in p else ('WalletAdjustment' if 'adjustments' in p else 'Wallet')
        table = 'WalletWithdrawals' if 'withdrawals' in p else ('WalletAdjustments' if 'adjustments' in p else 'Wallets')
        enums = ['TransactionStatus', 'WalletTransactionType']
        if 'withdrawals' in p:
            enums = ['WithdrawalStatus']
            action = 'RequestWithdrawal' if method == 'POST' else 'ReviewWithdrawal'
        elif 'adjustments' in p:
            action = 'AdjustBalance'
        elif 'topups' in p:
            action = 'CreateTopupVnpay'
        elif 'ipn' in p or 'webhook' in p:
            action = 'VnpayIpn' if 'ipn' in p else 'PaymentsWebhook'
        elif 'checkout/direct' in p:
            action = 'DirectCheckout'
        else:
            action = 'GetMyWallet' if 'me' in p else 'GetTransactions'

    # 7. Notification Service
    elif '/notification' in p or '/event-logs' in p or 'health/broker' in p:
        service = 'Notification'
        feature = 'Notifications'
        gateway_route = 'admin-event-logs-route' if 'event-logs' in p else ('admin-notifications-route' if '/admin/' in p else 'notification-notifications-route')
        controller = 'NotificationsController'
        service_iface = 'INotificationService'
        service_impl = 'NotificationService'
        entity = 'Notification'
        table = 'Notifications'
        enums = ['NotificationType', 'ChannelType']
        if 'devices' in p:
            action = 'RegisterDevice' if method == 'POST' else 'UnregisterDevice'
        elif 'preferences' in p:
            action = 'GetPreferences' if method == 'GET' else 'UpdatePreferences'
        elif 'me' in p:
            action = 'GetMyNotifications' if method == 'GET' else 'MarkAsRead'
        elif 'channels' in p:
            action = 'AdminGetChannel' if method == 'GET' else 'AdminUpdateChannel'
        elif 'templates' in p:
            action = 'AdminGetTemplates' if method == 'GET' else 'AdminCreateTemplate'
        elif 'event-logs' in p:
            action = 'AdminGetEventLogs' if '{id}' not in p else 'AdminGetEventLogDetail'
        elif 'health/broker' in p:
            action = 'AdminGetBrokerHealth'
        else:
            action = 'AdminGetNotifications'

    return {
        'service': service,
        'feature': feature,
        'gateway_route': gateway_route,
        'controller': controller,
        'action': action,
        'service_iface': service_iface,
        'service_impl': service_impl,
        'entity': entity,
        'table': table,
        'enums': enums
    }

def format_error_table(err_text, resource_name):
    lines = [
        "| HTTP Status | errorCode (SCREAMING_SNAKE_CASE) | message (100% English Sentence case) | Điều kiện kích hoạt trong Code Function |",
        "|:---:|:---|:---|:---|",
        "| `400` | `VAL_INVALID_INPUT` | \"One or more validation errors occurred.\" | Dữ liệu đầu vào vi phạm FluentValidation hoặc model binding. |",
        "| `401` | `UNAUTHORIZED` | \"Authentication token is missing, expired, or invalid.\" | Người dùng chưa đăng nhập hoặc JWT không hợp lệ. |",
        "| `403` | `FORBIDDEN` | \"You do not have permission to perform this action.\" | Người dùng không đủ quyền RBAC theo quy định. |",
        f"| `404` | `{resource_name.upper()}_NOT_FOUND` | \"{resource_name.capitalize()} not found with the specified ID.\" | Không tìm thấy bản ghi trong Database tương ứng. |",
        "| `500` | `INTERNAL_SERVER_ERROR` | \"An unexpected error occurred. Please try again later.\" | Lỗi hệ thống nội bộ chưa được xử lý. |"
    ]
    if err_text:
        for l in err_text.split('\n'):
            l = l.strip()
            if not l:
                continue
            m = re.match(r'(\d+)\s+([A-Z0-9_]+):\s*(.+)', l)
            if m:
                status = m.group(1)
                code = m.group(2)
                # Ensure SCREAMING_SNAKE_CASE without ERR_ prefix if present
                clean_code = re.sub(r'^ERR_', '', code)
                msg = m.group(3).strip()
                # Ensure sentence case
                if msg and msg[0].islower():
                    msg = msg[0].upper() + msg[1:]
                lines.insert(4, f"| `{status}` | `{clean_code}` | \"{msg}\" | Điều kiện nghiệp vụ đặc thù: {clean_code}. |")
    return "\n".join(lines)


def format_parameters(path, req_text):
    path_params = re.findall(r'\{([a-zA-Z0-9_-]+)\}', path)
    route_section = ""
    if path_params:
        route_section = "### 3.1. Route Parameters (Tham số đường dẫn)\n| Tên tham số | Kiểu dữ liệu | Bắt buộc? | Ràng buộc & Định dạng |\n|:---|:---|:---:|:---|\n"
        for p in path_params:
            route_section += f"| `{p}` | `Guid (UUID)` | Có | Mã định danh duy nhất (UUIDv4) |\n"
    else:
        route_section = "### 3.1. Route Parameters (Tham số đường dẫn)\n*Không có tham số đường dẫn.*\n"

    query_section = ""
    if 'GET' in path or 'search' in path or 'page' in req_text.lower():
        query_section = "### 3.2. Query Parameters (Tham số truy vấn)\n| Tên tham số | Kiểu dữ liệu | Mặc định | Ràng buộc & Khoảng giá trị |\n|:---|:---|:---:|:---|\n| `page` | `integer` | `1` | Số trang (tối thiểu 1) |\n| `pageSize` | `integer` | `20` | Kích thước trang ($1 \\le pageSize \\le 100$) |\n"
    else:
        query_section = "### 3.2. Query Parameters (Tham số truy vấn)\n*Không có tham số truy vấn.*\n"

    body_section = "### 3.3. Request Body (JSON Payload)\n"
    if req_text and any(x in req_text for x in ['{', ':']):
        # Clean request text to ensure valid codeblock
        body_section += f"```json\n{req_text}\n```\n"
    else:
        body_section += "*Không yêu cầu Request Body (Body rỗng).*\n"

    return f"{route_section}\n{query_section}\n{body_section}"


def format_response_section(res_text, method):
    if method == 'DELETE' or (res_text and '204' in res_text):
        return "### 4.1. Phản hồi Không có Body (`204 NoContent`)\nÁp dụng cho thao tác xóa hoặc cập nhật không cần trả payload dữ liệu.\n```http\nHTTP/1.1 204 No Content\n```"
    
    if res_text and 'items' in res_text and 'pagination' in res_text:
        return f"### 4.1. Phản hồi Phân trang (`ApiResponse<PagedData<T>>`)\nÁp dụng cho API tra cứu danh sách có phân trang:\n```json\n{res_text}\n```"

    if res_text:
        return f"### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)\nÁp dụng cho API trả về 1 đối tượng hoặc kết quả thực thi:\n```json\n{res_text}\n```"

    return "### 4.1. Phản hồi Thành công Đơn lẻ (`ApiResponse<T>`)\n```json\n{\n  \"success\": true,\n  \"statusCode\": 200,\n  \"message\": \"Operation completed successfully.\",\n  \"data\": {},\n  \"traceId\": \"00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01\",\n  \"timestamp\": \"2026-10-30T15:30:00Z\"\n}\n```"


def build_markdown(ep, meta):
    std_path, reason = standardize_endpoint(ep['path'], meta['service'])
    rbac = get_rbac(ep['method'], std_path)
    idempotency = get_idempotency(ep['method'])
    enum_table = generate_enum_section(meta['enums'])
    err_table = format_error_table(ep['err'], meta['entity'])
    params_section = format_parameters(std_path, ep['req'])
    response_section = format_response_section(ep['res'], ep['method'])

    doc = f"""# [{ep['method']}] {std_path}

> **Phân hệ thụ lý:** `{meta['service']}Service`  
> **Tên tính năng:** `{meta['feature']}`  
> **Mã tham chiếu Excel:** `{ep['ref_id']}`  
> **Trạng thái tài liệu:** `B_none (Chờ hoàn thiện & nghiệm thu)`  
> **Trạng thái triển khai:** `⏳ IN_PROGRESS`  

---

## 1. MÔ TẢ NGHIỆP VỤ & PHÂN QUYỀN

* **Mô tả chức năng:** {ep['desc']}
* **HTTP Method:** `{ep['method']}`
* **Đường dẫn chuẩn:** `{std_path}`
* **Đường dẫn gốc trong Excel:** `{ep['path']}` ({reason})
* **Quyền hạn truy cập (RBAC):** `{rbac}`
* **Yêu cầu Idempotency:** {idempotency}

---

## 2. DẤU VẾT MÃ NGUỒN (CODE TRACE & EXECUTION PATH)

Mọi thay đổi trong hàm nghiệp vụ (thêm validation, ném exception, thêm enum) bắt buộc phải cập nhật đồng bộ vào tài liệu này:

* **Microservice thụ lý:** `src/Services/{meta['service']}/`
* **Cổng Gateway điều phối:** `src/Services/Gateway/Gateway/appsettings.json` (Route: `{meta['gateway_route']}`)
* **Controller Action:** `{meta['service']}.Api/Controllers/{meta['controller']}.cs` $\\rightarrow$ `{meta['action']}()`
* **Application Interface:** `{meta['service']}.Application/Services/{meta['feature']}/{meta['service_iface']}.cs` $\\rightarrow$ `{meta['action']}Async()`
* **Service Implementation:** `{meta['service']}.Application/Services/{meta['feature']}/{meta['service_impl']}.cs` $\\rightarrow$ `{meta['action']}Async()`
* **Thực thể & Bảng DB:** `{meta['service']}.Domain/Entities/{meta['entity']}.cs` $\\rightarrow$ Bảng `{meta['table']}` trong PostgreSQL
* **Typed HTTP Client (nếu có):** N/A (Giao tiếp nội bộ trực tiếp qua DbContext)

---

## 3. QUY CHUẨN VALIDATION & THAM SỐ ĐẦU VÀO

{params_section}

---

## 4. PHONG BÌ DỮ LIỆU ĐẦU RA (RESPONSE ENVELOPE)

{response_section}

---

## 5. MA TRẬN MÃ LỖI (RFC 9110 ERROR MATRIX)

Frontend bắt buộc dựa vào cột `errorCode` để map và hiển thị giao diện phù hợp. Khi backend function bổ sung lệnh ném lỗi, phải cập nhật ngay vào bảng này:

{err_table}

---

## 6. DANH MỤC ENUM LIÊN QUAN (DOMAIN ENUMS)

{enum_table}

---

## 7. CHECKLIST HOÀN THÀNH & NGHIỆM THU (COMPLETION CHECKLIST)

- [ ] **1. Tầng Application:** `{meta['service_iface']}.cs` và `{meta['service_impl']}.cs` đã được triển khai hoàn chỉnh.
- [ ] **2. Tầng Api:** `{meta['controller']}.cs` ghép cặp 1-to-1, route số nhiều, summary XML ngắn gọn.
- [ ] **3. Bắt lỗi & Validation:** Toàn bộ mã lỗi trong ma trận ở Mục 5 đã được kiểm soát trong code.
- [ ] **4. Enum Mapping:** Toàn bộ enum ở Mục 6 được lưu integer trong DB và serialize PascalCase ở API.
- [ ] **5. Kiểm thử tự động:** `dotnet test` vượt qua 100% các bài test (Kèm tên file test: `{meta['feature']}Tests.cs`).
- [ ] **6. Định tuyến Gateway:** Route YARP `{meta['gateway_route']}` đã được cấu hình trong `appsettings.json` và test thông suốt.
- [ ] **7. Xác nhận của Sếp (Human Approval):** Đã kiểm thử thực tế và cho phép chuyển sang `docs/api/A_Active/`.

> **Trạng thái nghiệm thu:** `[ ⏳ IN_PROGRESS (Lưu tại B_none) ]`
"""
    return doc

generated_count = 0
service_file_counts = {}

for ep in parsed_endpoints:
    # Skip obsolete/hallucinated endpoints
    if ep['id'] in ['Row 147', 'Row 197', 'Row 198', 'Row 199']:
        print(f"Bỏ qua endpoint lỗi thời / ảo giác: {ep['id']} {ep['method']} {ep['path']}")
        continue

    meta = determine_service_and_trace(ep)
    svc = meta['service']
    
    # Filename format: {ep_id}_{METHOD}_{FEATURE_SLUG}.md
    clean_id = ep['id'].replace('Row ', 'R').replace(' ', '_')
    method = ep['method']
    path_slug = slugify(re.sub(r'\{.*?\}', '', ep['path']).replace('/api/v1/', '').replace('/', '_'))
    if not path_slug:
        path_slug = slugify(meta['action'])
    
    filename = f"{clean_id}_{method}_{path_slug}.md"
    filepath = os.path.join(BASE_DIR, svc, filename)
    
    doc_content = build_markdown(ep, meta)
    with open(filepath, 'w', encoding='utf-8') as out_f:
        out_f.write(doc_content)
        
    generated_count += 1
    service_file_counts[svc] = service_file_counts.get(svc, 0) + 1

# Now generate Log service (4 endpoints)
log_endpoints = [
    {
        'id': 'LOG-01',
        'method': 'GET',
        'path': '/api/v1/logs',
        'desc': 'Truy vấn danh sách nhật ký hệ thống tập trung (Centralized Logs) có phân trang và bộ lọc linh hoạt.',
        'ref_id': 'LOG-01',
        'req': '',
        'res': '{\n  "success": true,\n  "statusCode": 200,\n  "message": "Logs retrieved successfully.",\n  "data": {\n    "items": [\n      {\n        "id": "11111111-1111-1111-1111-000000000001",\n        "level": "Info",\n        "service": "CatalogService",\n        "message": "Product created successfully",\n        "timestamp": "2026-10-30T10:00:00Z"\n      }\n    ],\n    "pagination": {\n      "pageIndex": 1,\n      "pageSize": 20,\n      "totalCount": 100,\n      "totalPages": 5,\n      "hasPreviousPage": false,\n      "hasNextPage": true\n    }\n  }\n}',
        'err': '400 VAL_INVALID_INPUT: Invalid filter parameters provided.'
    },
    {
        'id': 'LOG-02',
        'method': 'GET',
        'path': '/api/v1/logs/{id}',
        'desc': 'Tra cứu chi tiết một bản ghi nhật ký hệ thống theo mã định danh UUID.',
        'ref_id': 'LOG-02',
        'req': '',
        'res': '{\n  "success": true,\n  "statusCode": 200,\n  "message": "Log entry retrieved successfully.",\n  "data": {\n    "id": "11111111-1111-1111-1111-000000000001",\n    "level": "Info",\n    "service": "CatalogService",\n    "message": "Product created successfully",\n    "payload": "{\\"productId\\": \\"uuid\\"}",\n    "timestamp": "2026-10-30T10:00:00Z"\n  }\n}',
        'err': '404 LOG_NOT_FOUND: Log entry not found with the specified ID.'
    },
    {
        'id': 'LOG-03',
        'method': 'GET',
        'path': '/api/v1/logs/event-types',
        'desc': 'Lấy danh mục các loại sự kiện hệ thống đã đăng ký theo dõi kiểm toán.',
        'ref_id': 'LOG-03',
        'req': '',
        'res': '{\n  "success": true,\n  "statusCode": 200,\n  "message": "Event types retrieved successfully.",\n  "data": [\n    {\n      "code": "AUTH_LOGIN",\n      "name": "User Login Event",\n      "isEnabled": true\n    }\n  ]\n}',
        'err': ''
    },
    {
        'id': 'LOG-04',
        'method': 'PUT',
        'path': '/api/v1/logs/event-types/{code}',
        'desc': 'Bật hoặc tắt trạng thái ghi nhật ký cho một loại sự kiện cụ thể.',
        'ref_id': 'LOG-04',
        'req': '{\n  "isEnabled": true\n}',
        'res': '{\n  "success": true,\n  "statusCode": 200,\n  "message": "Event type logging status updated successfully.",\n  "data": {\n    "code": "AUTH_LOGIN",\n    "isEnabled": true\n  }\n}',
        'err': '404 EVENT_TYPE_NOT_FOUND: Event type code not found.'
    }
]

for log_ep in log_endpoints:
    meta = {
        'service': 'Log',
        'feature': 'Log',
        'gateway_route': 'log-route',
        'controller': 'LogController',
        'action': 'QueryLogs' if log_ep['id'] == 'LOG-01' else ('GetLogById' if log_ep['id'] == 'LOG-02' else ('GetEventTypes' if log_ep['id'] == 'LOG-03' else 'ToggleEventType')),
        'service_iface': 'ILogService',
        'service_impl': 'LogService',
        'entity': 'LogEntry' if log_ep['id'] in ['LOG-01', 'LOG-02'] else 'LogEventType',
        'table': 'Logs' if log_ep['id'] in ['LOG-01', 'LOG-02'] else 'LogEventTypes',
        'enums': ['AlertSeverity']
    }
    filename = f"{log_ep['id']}_{log_ep['method']}_{slugify(log_ep['path'].replace('/api/v1/logs', ''))}.md".replace('_.md', '_ROOT.md')
    filepath = os.path.join(BASE_DIR, 'Log', filename)
    with open(filepath, 'w', encoding='utf-8') as out_f:
        out_f.write(build_markdown(log_ep, meta))
    generated_count += 1
    service_file_counts['Log'] = service_file_counts.get('Log', 0) + 1

# Now generate CheckHeal service (4 endpoints)
checkheal_endpoints = [
    {
        'id': 'CHK-01',
        'method': 'GET',
        'path': '/api/v1/healthcheck/status',
        'desc': 'Báo cáo tổng quan tình trạng sức khỏe toàn bộ hệ thống (8 Microservices & 8 Databases).',
        'ref_id': 'CHK-01',
        'req': '',
        'res': '{\n  "success": true,\n  "statusCode": 200,\n  "message": "System health status retrieved successfully.",\n  "data": {\n    "summary": {\n      "overallStatus": "healthy",\n      "totalServices": 8,\n      "enabledServices": 8,\n      "healthyServices": 8,\n      "totalDatabases": 8,\n      "enabledDatabases": 8,\n      "healthyDatabases": 8\n    }\n  }\n}',
        'err': ''
    },
    {
        'id': 'CHK-02',
        'method': 'GET',
        'path': '/api/v1/healthcheck/services',
        'desc': 'Lấy danh sách chi tiết trạng thái kiểm tra sức khỏe của các Microservices.',
        'ref_id': 'CHK-02',
        'req': '',
        'res': '{\n  "success": true,\n  "statusCode": 200,\n  "message": "Services status list retrieved successfully.",\n  "data": [\n    {\n      "name": "catalog",\n      "kind": "Service",\n      "status": "Healthy",\n      "latencyMs": 14\n    }\n  ]\n}',
        'err': ''
    },
    {
        'id': 'CHK-03',
        'method': 'GET',
        'path': '/api/v1/healthcheck/services/{name}',
        'desc': 'Xem chi tiết trạng thái kết nối và độ trễ của một dịch vụ cụ thể.',
        'ref_id': 'CHK-03',
        'req': '',
        'res': '{\n  "success": true,\n  "statusCode": 200,\n  "message": "Service status retrieved successfully.",\n  "data": {\n    "name": "catalog",\n    "kind": "Service",\n    "status": "Healthy",\n    "latencyMs": 14\n  }\n}',
        'err': '404 SERVICE_NOT_FOUND: Service target with the specified name was not found.'
    },
    {
        'id': 'CHK-04',
        'method': 'PUT',
        'path': '/api/v1/healthcheck/services/{name}/toggle',
        'desc': 'Bật hoặc tắt giám sát định kỳ cho một dịch vụ cụ thể.',
        'ref_id': 'CHK-04',
        'req': '{\n  "enabled": true,\n  "url": "http://catalog-service:8002/health"\n}',
        'res': '{\n  "success": true,\n  "statusCode": 200,\n  "message": "Service monitoring toggle updated successfully.",\n  "data": {\n    "name": "catalog",\n    "enabled": true\n  }\n}',
        'err': '404 SERVICE_NOT_FOUND: Service target with the specified name was not found.'
    }
]

for chk_ep in checkheal_endpoints:
    meta = {
        'service': 'CheckHeal',
        'feature': 'HealthCheck',
        'gateway_route': 'checkheal-route',
        'controller': 'HealthCheckController',
        'action': 'GetStatus' if chk_ep['id'] == 'CHK-01' else ('GetServices' if chk_ep['id'] == 'CHK-02' else ('GetServiceDetail' if chk_ep['id'] == 'CHK-03' else 'ToggleService')),
        'service_iface': 'IHealthService',
        'service_impl': 'HealthService',
        'entity': 'HealthTarget',
        'table': 'InMemoryHealthState',
        'enums': ['HealthStatus']
    }
    filename = f"{chk_ep['id']}_{chk_ep['method']}_{slugify(chk_ep['path'].replace('/api/v1/healthcheck', ''))}.md".replace('_.md', '_ROOT.md')
    filepath = os.path.join(BASE_DIR, 'CheckHeal', filename)
    with open(filepath, 'w', encoding='utf-8') as out_f:
        out_f.write(build_markdown(chk_ep, meta))
    generated_count += 1
    service_file_counts['CheckHeal'] = service_file_counts.get('CheckHeal', 0) + 1

# Ghi chú: YARP Gateway là edge reverse proxy thuần túy, không có controller/endpoint nghiệp vụ riêng.

print("\n" + "="*50)
print(f"Hoàn tất sinh {generated_count} file tài liệu API tại docs/api/B_none/")
print("Chi tiết số lượng file theo phân hệ:")
for s, count in sorted(service_file_counts.items()):
    print(f" - {s:15}: {count:3} files")
print("="*50)
