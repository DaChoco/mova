
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using System;
namespace Mova.Api.Hubs;

[Authorize]
public class RideChatHub : Hub
{
    public async Task JoinRide(string rideId)
    {
        var groupName = $"ride:{rideId}";

        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            groupName
        );
    }

    public async Task LeaveRide(string rideId)
    {
        await Groups.RemoveFromGroupAsync(
            Context.ConnectionId,
            $"ride:{rideId}");
    }
}
