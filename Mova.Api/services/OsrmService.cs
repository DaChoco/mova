
using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json.Serialization;

namespace Mova.Api.Services;

public sealed class OsrmService
{
    private readonly HttpClient _httpClient;

    public OsrmService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<OsrmRouteResult?> GetRouteAsync(
        double startLat,
        double startLon,
        double endLat,
        double endLon,
        CancellationToken cancellationToken = default)
    {
        // OSRM expects longitude first, followed by latitude.
        string coordinates =
            $"{Format(startLon)},{Format(startLat)};" +
            $"{Format(endLon)},{Format(endLat)}";

        string requestUrl =
            $"route/v1/driving/{coordinates}" +
            "?overview=full&geometries=geojson&steps=false";

        using var response = await _httpClient.GetAsync(
            requestUrl,
            cancellationToken);

        //response.EnsureSuccessStatusCode();
        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync(
                cancellationToken);

            throw new HttpRequestException(
                $"OSRM returned HTTP {(int)response.StatusCode} " +
                $"({response.ReasonPhrase}). Response: {errorBody}",
                null,
                response.StatusCode);
        }

        var result = await response.Content
            .ReadFromJsonAsync<OsrmResponse>(
                cancellationToken: cancellationToken);

        if (result?.Code != "Ok" ||
            result.Routes is not { Count: > 0 })
        {
            return null;
        }

        var route = result.Routes[0];

        return new OsrmRouteResult(
            route.Distance / 1000.0,
            route.Duration / 60.0,
            route.Geometry?.Coordinates ?? new List<List<double>>());
    }

    private static string Format(double value)
    {
        return value.ToString("R", CultureInfo.InvariantCulture);
    }

    private sealed class OsrmResponse
    {
        [JsonPropertyName("code")]
        public string? Code { get; set; }

        [JsonPropertyName("routes")]
        public List<OsrmRoute>? Routes { get; set; }
    }

    private sealed class OsrmRoute
    {
        [JsonPropertyName("distance")]
        public double Distance { get; set; }

        [JsonPropertyName("duration")]
        public double Duration { get; set; }

        [JsonPropertyName("geometry")]
        public OsrmGeometry? Geometry { get; set; }
    }

    private sealed class OsrmGeometry
    {
        [JsonPropertyName("coordinates")]
        public List<List<double>> Coordinates { get; set; } = [];
    }
}

public sealed record OsrmRouteResult(
    double DistanceKm,
    double DurationMinutes,
    List<List<double>> Coordinates);
