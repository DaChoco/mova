
using System.IO;
using System;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using DotNetEnv;

namespace Mova.Api.Helpers
{
    public class SupabaseStorageService
    {
        private readonly IConfiguration _configuration;
        private readonly HttpClient _httpClient;


        public SupabaseStorageService(
            IConfiguration configuration,
            HttpClient httpClient)
        {
            _configuration = configuration;
            _httpClient = httpClient;
        }

        public async Task<string> UploadProfilePictureAsync(
            string bucketName,
            string userId,
            string fileName,
            Stream fileStream,
            string contentType)
        {
            var supabaseUrl = _configuration["SUPABASE_URL"]?.Trim().TrimEnd('/', ';'); ;
            var serviceKey = _configuration["SUPABASE_SERVICE_KEY"]?.Trim().TrimEnd('/', ';'); ;

            Console.WriteLine($"Supabase URL: '{supabaseUrl}'");

            Console.WriteLine(
                $"Service key prefix: " +
                $"{serviceKey?.Substring(0, Math.Min(10, serviceKey.Length))}");

            Console.WriteLine(
                $"Service key length: {serviceKey?.Length}");

            if (string.IsNullOrEmpty(supabaseUrl))
                throw new InvalidOperationException("Supabase URL is not configured.");

            if (string.IsNullOrEmpty(serviceKey))
                throw new InvalidOperationException("Supabase service key is not configured.");

            var filePath = $"{userId}/{fileName}";

            var url =
                $"{supabaseUrl}/storage/v1/object/{bucketName}/{filePath}";


            using var request = new HttpRequestMessage(HttpMethod.Post, url);

            request.Headers.Add("apikey", serviceKey);
            request.Headers.Add("x-upsert", "true");

            request.Content = new StreamContent(fileStream);
            request.Content.Headers.ContentType =
                new MediaTypeHeaderValue(contentType);

            using var response = await _httpClient.SendAsync(request);

            var responseBody =
                await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                throw new Exception(
                    $"Supabase upload failed: " +
                    $"{(int)response.StatusCode} " +
                    $"{response.StatusCode} - {responseBody}");
            }

            // Public URL
            return $"{supabaseUrl}/storage/v1/object/public/{bucketName}/{filePath}";
        }
    }
}