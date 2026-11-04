# Chuyen De 03: Bo Loc, Validation & Tuan Tu Hoa Enum (Validation & Serialization Architecture)

Chuyen de nay huong dan chi tiet ve ranh gioi xac thuc du lieu dau vao (Boundary Input Validation), bo nha loi chong ro ri thong tin he thong (`ApiValidationProblemFactory`), va co che tuan tu hoa Enum hai chieu nghiem ngat (`PascalCaseJsonStringEnumConverter`).

---

## 1. Ranh Gioi Xac Thuc Du Lieu Dau Vao (Boundary Validation)

He thong Nexus tuan thu nguyen tac: **Du lieu chi duoc coi la an toan sau khi da vuot qua tang kiem tra tai ranh gioi API**.

Moi du lieu gui len tu Client trong request body deu duoc khai bao bang cac C# Record tai `User.Application/Services/{Feature}/{Feature}Requests.cs` va duoc gan cac thuoc tinh DataAnnotations kem thong bao loi tieng Anh Sentence case:

```csharp
// src/Services/User/User.Application/Services/Auth/AuthRequests.cs
public sealed record RegisterApiRequest
{
    [Required(ErrorMessage = "Email is required.")]
    [EmailAddress(ErrorMessage = "Email address is invalid.")]
    [MaxLength(255, ErrorMessage = "Email must not exceed 255 characters.")]
    public string Email { get; init; } = default!;

    [Required(ErrorMessage = "Password is required.")]
    [MinLength(8, ErrorMessage = "Password must be at least 8 characters long.")]
    [MaxLength(100, ErrorMessage = "Password must not exceed 100 characters.")]
    public string Password { get; init; } = default!;

    [Required(ErrorMessage = "First name is required.")]
    [MaxLength(150, ErrorMessage = "First name must not exceed 150 characters.")]
    public string FirstName { get; init; } = default!;

    [Required(ErrorMessage = "Last name is required.")]
    [MaxLength(150, ErrorMessage = "Last name must not exceed 150 characters.")]
    public string LastName { get; init; } = default!;

    [Phone(ErrorMessage = "Phone number is invalid.")]
    [MaxLength(50, ErrorMessage = "Phone number must not exceed 50 characters.")]
    public string? PhoneNumber { get; init; }
}
```

### Nguyen tac viet thong bao loi:
1. **100% Tieng Anh:** Khong dung tieng Viet trong bat ky thong bao loi nao.
2. **Sentence case:** Chi viet hoa duy nhat chu cai dau tien cua cau thong bao (vi du: `"Email address is invalid."`).
3. **Gia tri dau vao khong hop le:** Tra ve ma HTTP 400 Bad Request voi `errorCode = "VAL_INVALID_INPUT"`.

---

## 2. Chong Ro Ri Thong Tin Parser Qua `ApiValidationProblemFactory`

Mac dinh, khi ASP.NET Core gap loi cu phap JSON (vi du client gui sai dau ngoac, truyen chuoi vao truong so nguyen), bo parser `System.Text.Json` se nem ra cac thong bao loi tiet lo chi tiet ky thuat noi bo:
- `The JSON value could not be converted to System.Int32. Path: $.age | LineNumber: 0 | BytePositionInLine: 15.`

Viec nay co the giup tin tac phan tich duoc cau truc memory, ten class ben trong C#, va thu vien parser dang dung.

### Giai phap: Thay the `InvalidModelStateResponseFactory`

Trong `Program.cs`, UserService cau hinh:
```csharp
builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = ApiValidationProblemFactory.Create;
    });
```

Lop `ApiValidationProblemFactory` kiem tra toan bo loi trong `ModelState`. Neu phat hien bat ky chuoi nao chua cac tu khoa ro ri nhu `LineNumber`, `BytePositionInLine`, `Path: $`, `could not be converted to`, no se thay the bang thong diep an toan: `"The request body is not valid."`:

```csharp
// src/Services/User/User.Api/Common/ApiValidationProblemFactory.cs
public static class ApiValidationProblemFactory
{
    public const string GenericDetail = "One or more validation errors occurred.";
    public const string UnreadableBodyDetail = "The request body is not valid.";

    public static IActionResult Create(ActionContext context)
    {
        var traceId = Activity.Current?.Id ?? context.HttpContext.TraceIdentifier;
        var errors = CollectErrors(context.ModelState);
        var messages = errors.Values.SelectMany(v => v).ToList();
        var detail = messages.Any(m => m == UnreadableBodyDetail)
            ? UnreadableBodyDetail
            : (messages.Count > 0 ? string.Join(" ", messages) : GenericDetail);

        var problem = new
        {
            type = "https://tools.ietf.org/html/rfc9110#section-15.5.1",
            title = "One or more validation errors occurred.",
            status = StatusCodes.Status400BadRequest,
            errorCode = "VAL_INVALID_INPUT",
            detail,
            errors = errors.Count > 0 ? errors : null,
            traceId,
            timestamp = DateTimeOffset.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        };

        return new ObjectResult(problem)
        {
            StatusCode = StatusCodes.Status400BadRequest,
            ContentTypes = { "application/problem+json" }
        };
    }

    private static bool LeaksInternals(string message) =>
        message.Contains("LineNumber", StringComparison.Ordinal) ||
        message.Contains("BytePositionInLine", StringComparison.Ordinal) ||
        message.Contains("Path: $", StringComparison.Ordinal) ||
        message.Contains("could not be converted to", StringComparison.OrdinalIgnoreCase);
}
```

---

## 3. Tuan Tu Hoa Enum Hai Chieu Nghiem Ngat (`PascalCaseJsonStringEnumConverter`)

REST API trong he thong Nexus tuan thu chat che:
1. **Chieu Ra (Server -> Client):** 100% gia tri Enum trong JSON Response phai la chuoi **PascalCase** (vi du: `"Active"`, `"PendingVerification"`). Tuyet doi khong tra ve so nguyen (`0, 1`) hoac chuoi SCREAMING_SNAKE_CASE (`"ACTIVE"`, `"PENDING_VERIFICATION"`).
2. **Chieu Vao (Client -> Server):** Chap nhan chuoi khong phan biet hoa thuong, tu dong xoa dau gach duoi (vi du client gui `"pending_verification"` hay `"PENDING_VERIFICATION"` deu parse thanh cong ve `UserStatus.PendingVerification`).
3. **Cam nhan so nguyen:** `allowIntegerValues: false`. Neu client gui `status: 1`, bo chuyen doi se tu choi ngay lap tuc va nem thong bao tieng Anh neu ro toan bo gia tri hop le.

### Dang ky toan cuc tren he thong

Trong `User.Api/Extensions/ServiceDefaultsExtensions.cs`:
```csharp
services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.Converters.Add(new PascalCaseJsonStringEnumConverter(allowIntegerValues: false));
});
services.Configure<Microsoft.AspNetCore.Mvc.JsonOptions>(options =>
{
    options.JsonSerializerOptions.Converters.Add(new PascalCaseJsonStringEnumConverter(allowIntegerValues: false));
});
```

### Trien khai ben trong `PascalCaseJsonStringEnumConverter.cs`:

```csharp
// Ghi dữ liệu ra (Server -> Client):
public override void Write(Utf8JsonWriter writer, T value, JsonSerializerOptions options)
{
    writer.WriteStringValue(value.ToString()); // Ghi ra tên PascalCase của Enum
}

// Đọc dữ liệu vào (Client -> Server):
public override T Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
{
    if (reader.TokenType == JsonTokenType.String)
    {
        var stringValue = reader.GetString();
        var trimmed = stringValue.Trim();

        // 1. Thử parse trực tiếp (case-insensitive)
        if (Enum.TryParse<T>(trimmed, ignoreCase: true, out var result) && Enum.IsDefined(typeof(T), result))
        {
            return result;
        }

        // 2. Tự động loại bỏ dấu gạch dưới nếu client gửi SCREAMING_SNAKE_CASE
        if (trimmed.Contains('_'))
        {
            var withoutUnderscore = trimmed.Replace("_", "");
            if (Enum.TryParse<T>(withoutUnderscore, ignoreCase: true, out var resultWithoutUnderscore) && 
                Enum.IsDefined(typeof(T), resultWithoutUnderscore))
            {
                return resultWithoutUnderscore;
            }
        }

        // 3. Ném ngoại lệ nêu rõ các giá trị hợp lệ nếu không khớp
        throw new JsonException($"Invalid value '{stringValue}' for enum '{typeof(T).Name}'. Valid values are: {string.Join(", ", Enum.GetNames<T>())}.");
    }

    throw new JsonException($"Expected string value for enum '{typeof(T).Name}', but got {reader.TokenType}. Valid values are: {string.Join(", ", Enum.GetNames<T>())}.");
}
```

---

## 4. Cac Ham Mo Rong Tien Ich (`HttpContextExtensions`)

De giup cac Controller Action va Filter trich xuat thong tin danh tinh mot cach an toan, file `User.Api/Extensions/HttpContextExtensions.cs` cung cap cac phuong thuc mo rong:

```csharp
// Lấy Guid của người dùng hiện tại từ Claims hoặc Headers
public static Guid? GetUserId(this HttpContext context);

// Lấy Email của người dùng
public static string? GetUserEmail(this HttpContext context);

// Lấy danh sách Roles dạng mảng chữ thường
public static string[] GetUserRoles(this HttpContext context);

// Kiểm tra nhanh quyền Admin hoặc Staff
public static bool IsAdmin(this HttpContext context);

// Lấy TraceId phân tán (W3C Activity.Current.Id)
public static string? GetTraceId(this HttpContext context);
```

Cac ham nay giup Controller giu duoc phong cach "sieu mong" (Thin Controller), khong bi phuc tap hoa boi cac doan ma xu ly Claims thu cong.
