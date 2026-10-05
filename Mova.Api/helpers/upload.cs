using System.Threading.Tasks;
using System;

public class SupabaseStorageService
{
    public async Task<string> UploadProfilePictureAsync(
        String bucketName,
        String userId,
        String fileName)
    {
        var supabaseUrl = "https://zeedqugdftxrbscmhgmq.supabase.co";
        var supabaseKey = "YOUR_SUPABASE_KEY";

        var url = $"{supabaseUrl}/storage/v1/object/{bucketName}/{userId}/{fileName}";

        using var client = new HttpClient();

        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", supabaseKey);

        client.DefaultRequestHeaders.Add("apikey", supabaseKey);

        await using var fileStream = File.OpenRead(filePath);

        using var content = new StreamContent(fileStream);

        content.Headers.ContentType =
            new MediaTypeHeaderValue("image/jpeg");

        var response = await client.PostAsync(url, content);

        response.EnsureSuccessStatusCode();

        return $"{supabaseUrl}/storage/v1/object/public/{bucketName}/{fileName}";
    }
}