
using System.IO;
using System;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using DotNetEnv;
using System.Linq;
using System.Text;
using System.Text.Json;

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

        private async Task DeleteFolderContentsAsync(
    string supabaseUrl,
    string serviceKey,
    string bucketName,
    string folder,
    string? excludeFileName = null)
        {
            while (true)
            {
                var listUrl = $"{supabaseUrl}/storage/v1/object/list/{bucketName}";

                using var listRequest = new HttpRequestMessage(HttpMethod.Post, listUrl);
                listRequest.Headers.Add("apikey", serviceKey);
                listRequest.Headers.Add("Authorization", $"Bearer {serviceKey}");
                listRequest.Content = new StringContent(
                    JsonSerializer.Serialize(new { prefix = folder, limit = 100, offset = 0 }),
                    Encoding.UTF8,
                    "application/json");

                using var listResponse = await _httpClient.SendAsync(listRequest);
                var listBody = await listResponse.Content.ReadAsStringAsync();

                if (!listResponse.IsSuccessStatusCode)
                    throw new Exception($"Supabase list failed: {(int)listResponse.StatusCode} - {listBody}");

                using var doc = JsonDocument.Parse(listBody);

                var paths = doc.RootElement.EnumerateArray()
                    .Select(e => e.GetProperty("name").GetString())
                    .Where(n => !string.IsNullOrEmpty(n) && n != excludeFileName)
                    .Select(n => $"{folder}/{n}")
                    .ToList();

                if (paths.Count == 0)
                    return;
                var deleteUrl = $"{supabaseUrl}/storage/v1/object/{bucketName}";

                using var deleteRequest = new HttpRequestMessage(HttpMethod.Delete, deleteUrl);
                deleteRequest.Headers.Add("apikey", serviceKey);
                deleteRequest.Headers.Add("Authorization", $"Bearer {serviceKey}");
                deleteRequest.Content = new StringContent(
                    JsonSerializer.Serialize(new { prefixes = paths }),
                    Encoding.UTF8,
                    "application/json");

                using var deleteResponse = await _httpClient.SendAsync(deleteRequest);
                var deleteBody = await deleteResponse.Content.ReadAsStringAsync();

                if (!deleteResponse.IsSuccessStatusCode)
                    throw new Exception($"Supabase delete failed: {(int)deleteResponse.StatusCode} - {deleteBody}");

                if (excludeFileName != null || paths.Count < 100)
                    return;
            }
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

            // Upload succeeded: remove every other file in the user's folder
            await DeleteFolderContentsAsync(supabaseUrl, serviceKey, bucketName, userId, excludeFileName: fileName);

            // Public URL
            return $"{supabaseUrl}/storage/v1/object/public/{bucketName}/{filePath}";
        }
    }
}