using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Mova.Api.Data;
using Mova.Api.Helpers;
using Microsoft.Extensions.FileProviders;
using DotNetEnv;

Env.Load(Path.Combine(Directory.GetCurrentDirectory(), ".env"));
var builder = WebApplication.CreateBuilder(args);


// Service Registration for dependency injection, including controllers, database contexts, JWT authentication, and CORS policies.

builder.Services.AddControllers();
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer<
        Mova.Api.Helpers.BearerSecuritySchemeTransformer>();
});

builder.Services.Configure<MongoSettings>(builder.Configuration.GetSection("MongoDB"));
builder.Services.AddSingleton<MongoDbContext>();
builder.Services.AddHttpClient<SupabaseStorageService>();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("Default")));

var jwt = builder.Configuration.GetSection("Jwt");

// Configure JWT authentication to be used as bearer tokens.
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt["Issuer"],
            ValidAudience = jwt["Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt["Key"]!))
        };
    });

builder.Services.AddAuthorization();

builder.Services.Configure<MongoSettings>(options =>
{
    options.ConnectionString =
        builder.Configuration["MONGODB_CONNECTION_STRING"]
        ?? throw new InvalidOperationException(
            "MONGODB_CONNECTION_STRING is not configured.");

    options.DatabaseName =
        builder.Configuration["MONGO_MESSAGE_DATABASE_NAME"]
        ?? throw new InvalidOperationException(
            "MONGO_MESSAGE_DATABASE_NAME is not configured.");
});

builder.Services.AddSingleton<MongoDbContext>();

builder.Services.AddEndpointsApiExplorer();

builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterWeb", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// HTTP request pipeline configuration for development and production environments.
// implementing swagger for API documentation and testing in development mode, enabling CORS, HTTPS redirection, static file serving, authentication, and authorization.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();

    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint(
            "/openapi/v1.json",
            "Mova API v1");

        options.RoutePrefix = "swagger";
    });
}

app.UseCors("FlutterWeb");
app.UseHttpsRedirection();



app.UseAuthentication();   // must come before UseAuthorization
app.UseAuthorization();
app.MapControllers();



app.Run();