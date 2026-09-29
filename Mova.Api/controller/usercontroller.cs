using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mova.Api.Data;

namespace Mova.Api.Controllers;

[ApiController]
[Route("api/user")]
[Authorize]
public class UserController : ControllerBase
{
    private readonly AppDbContext _db;

    public UserController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(int id)
    {
        var user = await _db.Users.FindAsync(id);
        if (user is null)
            return NotFound(new { success = false });

        return Ok(new
        {
            success = true,
            user = new
            {
                userId = user.UserId,
                studentNumber = user.StudentNumber,
                firstName = user.FirstName,
                surname = user.Surname,
                carID = user.CarId
            }
        });
    }
}