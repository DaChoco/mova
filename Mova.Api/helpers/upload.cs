
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
            var supabaseUrl = _configuration["SUPABASE_URL"];
            var serviceKey = _configuration["SUPABASE_SERVICE_KEY"];

            if (string.IsNullOrEmpty(supabaseUrl))
                throw new InvalidOperationException("Supabase URL is not configured.");

            if (string.IsNullOrEmpty(serviceKey))
                throw new InvalidOperationException("Supabase service key is not configured.");

            var filePath = $"{userId}/{fileName}";

            var url =
                $"{supabaseUrl}/storage/v1/object/{bucketName}/{filePath}";

            using var request = new HttpRequestMessage(
                HttpMethod.Post,
                url);

            request.Headers.Authorization =
                new AuthenticationHeaderValue("Bearer", serviceKey);

            request.Headers.Add("apikey", serviceKey);

            request.Headers.Add("x-upsert", "true");

            var content = new StreamContent(fileStream);

            content.Headers.ContentType =
                new MediaTypeHeaderValue(contentType);

            request.Content = content;

            var response = await _httpClient.SendAsync(request);

            var responseBody = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                throw new Exception(
                    $"Supabase upload failed: {response.StatusCode} - {responseBody}");
            }

            // Public URL
            return $"{supabaseUrl}/storage/v1/object/public/{bucketName}/{filePath}";
        }
    }
}