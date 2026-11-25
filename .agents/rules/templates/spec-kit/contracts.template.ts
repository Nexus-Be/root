/**
 * Hợp Đồng Kiểu Dữ Liệu Tĩnh (Static Type Contracts)
 * Vị trí lưu trữ quy chuẩn: specs/[tên-tính-năng]/contracts.ts
 * 
 * LƯU Ý CHO AGENT: File này là bản thiết kế kiểu dữ liệu bất biến.
 * AI Agent chỉ cần đọc file này là nắm 90% logic cần cài đặt mà không cần đọc source code chi tiết.
 */

// 1. Domain Primitive / Enums
export type EntityStatus = 'Active' | 'Pending' | 'Suspended';

// 2. Request DTOs
export interface CreateEntityRequest {
  name: string;
  code: string;
  metadata?: Record<string, unknown>;
}

export interface UpdateEntityRequest {
  name?: string;
  status?: EntityStatus;
  metadata?: Record<string, unknown>;
}

// 3. Response DTOs
export interface EntityResponse {
  id: string;
  name: string;
  code: string;
  status: EntityStatus;
  createdAt: string;
  updatedAt?: string;
}

// 4. Service / Interface Contract
export interface IEntityService {
  getById(id: string): Promise<EntityResponse>;
  create(request: CreateEntityRequest): Promise<EntityResponse>;
  update(id: string, request: UpdateEntityRequest): Promise<EntityResponse>;
  delete(id: string): Promise<boolean>;
}
