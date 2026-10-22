
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mova.Api.Services;

namespace Mova.Api.Controllers;

[ApiController]
[Route("api/routes")]
[Authorize]
public class RoutesController : ControllerBase
{
    private readonly OsrmService _osrmService;
    private readonly ILogger<RoutesController> _logger;

    public RoutesController(
        OsrmService osrmService,
        ILogger<RoutesController> logger)
    {
        _osrmService = osrmService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> GetRoute(
        [FromQuery] double startLat,
        [FromQuery] double startLon,
        [FromQuery] double endLat,
        [FromQuery] double endLon,
        CancellationToken cancellationToken)
    {
        if (!IsValidCoordinate(startLat, startLon) ||
            !IsValidCoordinate(endLat, endLon))
        {
            return BadRequest(new
            {
                message = "One or more coordinates are invalid."
            });
        }

        try
        {
            var route = await _osrmService.GetRouteAsync(
                startLat,
                startLon,
                endLat,
                endLon,
                cancellationToken);

            if (route is null)
            {
                return UnprocessableEntity(new
                {
                    message = "OSRM could not find a driving route."
                });
            }

            return Ok(new
            {
                distanceKm = Math.Round(route.DistanceKm, 2),
                durationMinutes = Math.Round(
                    route.DurationMinutes, 1),
                coordinates = route.Coordinates
            });
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(
                ex,
                "Could not communicate with the OSRM service.");

            return StatusCode(
                StatusCodes.Status503ServiceUnavailable,
                new
                {
                    message = "The routing service is unavailable."
                });
        }
        catch (TaskCanceledException)
            when (!cancellationToken.IsCancellationRequested)
        {
            return StatusCode(
                StatusCodes.Status503ServiceUnavailable,
                new
                {
                    message = "The routing service timed out."
                });
        }
    }

    private static bool IsValidCoordinate(
        double latitude,
        double longitude)
    {
        return double.IsFinite(latitude) &&
               double.IsFinite(longitude) &&
               latitude >= -90 &&
               latitude <= 90 &&
               longitude >= -180 &&
               longitude <= 180;
    }
}
