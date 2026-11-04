# Chuyen De 00: Kien Truc Edge Proxy & YARP Engine (Edge Proxy & YARP Architecture)

Chuyen de nay giai thich ve vi tri kien truc cua Edge API Gateway trong he sinh thai Nexus, co che van hanh cua bo dinh tuyen Microsoft YARP 2.3.0, quy tac bat bien Zero-Controller Invariant, va danh muc 9 cum dich vu downstream.

---

## 1. Vai Tro Cua Edge Reverse Proxy Trong He Sinh Thai Nexus

Trong mot he thong gom nhieu vi dich vu doc lap, viec de client (Web frontend, Mobile app) goi truc tiep den tung microservice gay ra nhieu bat cap:
1. Client phai luu giu va quan ly 9 dia chi URL khac nhau voi cac cong mang phuc tap.
2. Moi microservice phai tu cau hinh CORS, tu giai ma JWT, tu quan ly SSL/TLS va tu lap hang rao bao ve chong tan cong DoS.
3. Khi can doi cong mang hoac tai cau truc backend, client bi anh huong truc tiep.

### Giai phap: Edge Reverse Proxy
Nexus API Gateway dung tai bien mang (Edge), dong vai tro la mot **Reverse Proxy phi trang thai (Stateless)** tren cong duy nhat `8080`:
- **Diem vao duy nhat (Single Public Ingress):** Client chi can biet duy nhat dia chi `http://localhost:8080`.
- **An giu ha tang backend:** Toan bo dia chi IP, cong mang noi bo (8001-8009) va ten container cua cac vi dich vu hoan toan duoc giau kin sau Gateway.
- **Tach biet quan quyen:** Gateway dam nhan toan bo cac tac vu bien (SSL termination, CORS, Rate limiting, Anti-spoofing, JWT validation), giup backend microservices tap trung 100% vao nghiep vu nghiem ngat.

---

## 2. Kien Truc Microsoft YARP 2.3.0 (Yet Another Reverse Proxy)

Thay vi su dung Ocelot (thu vien cu co do tre cao va it duoc Microsoft cap nhat) hoac viet proxy thu cong bang `HttpClient`, Nexus su dung **Microsoft YARP 2.3.0**.

YARP duoc Microsoft thiet ke truc tiep tren nen tang ASP.NET Core Kestrel HTTP server, mang lai toc do chuyen tiep goi tin cuc nhanh, tan dung toi da HTTP/2 va socket pooling, dong thoi tieu ton it bo nho RAM nhat.

### Cau truc khai bao trong `Gateway/appsettings.json`

Kien truc YARP duoc to chuc thanh 2 phan tach biet: `Routes` (Quy tac khop duong dan) va `Clusters` (Dia chi dich can chuyen tiep).

#### A. Khai bao Routes (Route Matching)
Moi route dai dien cho mot mau URL ma Gateway lang nghe:

```json
"ReverseProxy": {
  "Routes": {
    "auth-route": {
      "ClusterId": "user-cluster",
      "Match": {
        "Path": "/api/v1/auth/{**catch-all}"
      }
    },
    "categories-route": {
      "ClusterId": "catalog-cluster",
      "Match": {
        "Path": "/api/v1/categories/{**catch-all}"
      }
    },
    "carts-route": {
      "ClusterId": "commerce-cluster",
      "Match": {
        "Path": "/api/v1/carts/{**catch-all}"
      }
    }
  }
}
```

#### B. Khai bao Clusters (Downstream Destinations)
Moi cluster dinh nghia dia chi backend thuc te phia sau mang noi bo:

```json
"Clusters": {
  "user-cluster": {
    "Destinations": {
      "user-service": {
        "Address": "http://localhost:8001"
      }
    }
  },
  "catalog-cluster": {
    "Destinations": {
      "catalog-service": {
        "Address": "http://localhost:8002"
      }
    }
  },
  "commerce-cluster": {
    "Destinations": {
      "commerce-service": {
        "Address": "http://localhost:8003"
      }
    }
  }
}
```

---

## 3. Quy Tac Bat Bien: Cam Tuyet Doi Controller Tai Gateway (Zero-Controller Invariant)

Trong ma nguon cua `src/Services/Gateway/Gateway/`, lap trinh vien se khong tim thay bat ky file Controller hay action method nao. Day la mot **quy tac kien truc bat bien (Zero-Controller Invariant)**.

### Ly do kien truc:
1. **Tranh tao diem nghen (Bottleneck Anti-Pattern):**
   Neu tao Controller tai Gateway de hung request, parse request body thanh model C#, roi lai dung HttpClient goi tiep sang backend service, he thong se phai serialze/deserialize du lieu 2 lan lien tiep tren bo nho RAM. Dieu nay gay cham tre tram trong va de lam can kiet tai nguyen CPU cua Gateway khi co luong truy cap lon.
2. **Kestrel Streaming Pipeline:**
   YARP chuyen tiep truc tiep luong byte (stream) giua Client va Backend microservice ma khong can giai ma toan bo payload vao bo nho, giup Gateway xu ly hang chuc ngan request dong thoi mot cach nhe nhang.
3. **Phan tach ro rang trach nhiem:**
   Gateway khong so huu du lieu va khong chua logic nghiep vu. Moi su thay doi ve validate nghiep vu hay hop dong DTO deu nam tron ven o backend microservice tuong ung, Gateway hoan toan khong phai bien dich lai moi khi backend co them DTO moi.

---

## 4. Danh Muc 9 Cum Dich Vu Downstream (Downstream Routing Catalog)

Gateway dinh tuyen toi 9 cum vi dich vu backend theo dac ta phan bo cong bat bien sau:

| STT | Cum Dich Vu (ClusterId) | Dia Chi Mac Dinh | Danh Muc Routes Dai Dien | Trach Nhiem Nghiep Vu |
|:---:|:---|:---|:---|:---|
| 1 | `user-cluster` | `http://localhost:8001` | `/api/v1/auth/**`, `/api/v1/me/**`, `/api/v1/users/**`, `/api/v1/sellers/**`, `/api/v1/admin/users/**`, `/api/v1/admin/roles/**`, `/api/v1/admin/seller-registrations/**` | Dinh danh, xac thuc JWT, ho so ca nhan, quan tri admin, dang ky nguoi ban. |
| 2 | `catalog-cluster` | `http://localhost:8002` | `/api/v1/categories/**`, `/api/v1/products/**`, `/api/v1/variants/**`, `/api/v1/images/**`, `/api/v1/seller/products/**` | Danh muc hang hoa, san pham, bien the san pham, kho ao san sang ban. |
| 3 | `commerce-cluster` | `http://localhost:8003` | `/api/v1/carts/**`, `/api/v1/orders/**` | Gio hang mua sam, dat hang, chi tiet don hang, huy don. |
| 4 | `log-cluster` | `http://localhost:8004` | `/api/v1/logs/**` | Nhat ky he thong, nhat ky kiem toan tap trung (Append-only). |
| 5 | `auction-cluster` | `http://localhost:8005` | `/api/v1/auctions/**` | Phien dau gia, dat gia (Bids), lich su dau gia, chot phien. |
| 6 | `fulfillment-cluster` | `http://localhost:8006` | `/api/v1/warehouses/**`, `/api/v1/shipments/**`, `/api/v1/inventories/**` | Kho bai vat ly, khoi tao ton kho SKU, quan ly van don va cuoc phi. |
| 7 | `notification-cluster` | `http://localhost:8007` | `/api/v1/notifications/**`, `/api/v1/admin/notifications/**`, `/api/v1/admin/health/**` | Thong bao in-app, gui email OTP/SMTP, thiet bi nhan tin. |
| 8 | `wallet-cluster` | `http://localhost:8008` | `/api/v1/wallets/**`, `/api/v1/admin/wallets/**` | Vi dien tu, so du, nap tien VNPay, yeu cau rut tien, thanh toan truc tiep. |
| 9 | `checkheal-cluster` | `http://localhost:8009` | `/api/v1/healthcheck/**`, `/health/**` | Giam sat trang thai hoat dong, keep-alive giu ket noi CSDL Neon Cloud. |

---

## 5. Dang Ky Reverse Proxy Trong `Gateway/Program.cs`

Qua trinh khoi tao va gan bo chuyen doi YARP duoc thuc hien qua 2 dong lenh chinh:

```csharp
// 1. Đăng ký YARP vào DI Container và nạp cấu hình từ appsettings.json
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"))
    .AddTransforms(b => b.AddIdentityPropagation());

// 2. Kích hoạt Endpoint Routing của Reverse Proxy ở cuối pipeline
var app = builder.Build();
// ... các middlewares ...
app.MapReverseProxy();
app.Run();
```

Khi request vuot qua toan bo cac lop middleware kiem soat cua Gateway, `app.MapReverseProxy()` se tiep quan request va tien hanh streaming goi tin sang dich den tuong ung.
