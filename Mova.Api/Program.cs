using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Microsoft.IdentityModel.Tokens;
using Mova.Api.Data;
using Mova.Api.Helpers;
using Microsoft.Extensions.FileProviders;
using DotNetEnv;
using Mova.Api.Services;
using Mova.Api.Hubs;

Env.Load(
    Path.Combine(Directory.GetCurrentDirectory(), ".env"),
    new DotNetEnv.LoadOptions(
        setEnvVars: true,
        clobberExistingVars: false
    )
);
var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddEnvironmentVariables();

var connectionString =
    builder.Configuration.GetConnectionString("Default");

if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "ConnectionStrings:Default is missing.");
}

var db = new NpgsqlConnectionStringBuilder(connectionString);



// Service Registration for dependency injection, including controllers, database contexts, JWT authentication, and CORS policies.

builder.Services.AddControllers();
builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer<
        Mova.Api.Helpers.BearerSecuritySchemeTransformer>();
});

builder.Services.AddSignalR();
builder.Services.Configure<MongoSettings>(builder.Configuration.GetSection("MongoDB"));
builder.Services.AddSingleton<MongoDbContext>();
builder.Services.AddHttpClient<SupabaseStorageService>();


builder.Services.AddHttpClient<OsrmService>(client =>
{
    var baseUrl = builder.Configuration["Osrm:BaseUrl"]
        ?? "https://router.project-osrm.org";

    client.BaseAddress = new Uri(
        baseUrl.TrimEnd('/') + "/");

    client.Timeout = TimeSpan.FromSeconds(30);

    // Identify Mova when requesting routes from OSRM.
    client.DefaultRequestHeaders.UserAgent.ParseAdd(
        "MovaCarpoolApp/1.0");
});


builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("Default")
        ?? throw new InvalidOperationException(
            "Connection string 'Default' is not configured.")));

var jwt = builder.Configuration.GetSection("Jwt");

// Configure JWT authentication to be used as bearer tokens.
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme);


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
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwt["Key"]!)
            )
        };

        // Allow SignalR browser connections to authenticate
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken =
                    context.Request.Query["access_token"];

                var path = context.HttpContext.Request.Path;

                if (!string.IsNullOrEmpty(accessToken) &&
                    path.StartsWithSegments("/hubs/ride-chat"))
                {
                    context.Token = accessToken;
                }

                return Task.CompletedTask;
            }
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
        policy
            .WithOrigins(
                "http://localhost:58608",
                "http://localhost:58609",
                "http://localhost:58610",
                "http://localhost:6111"
            )
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
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
app.MapHub<RideChatHub>("/hubs/ride-chat");



app.Run();