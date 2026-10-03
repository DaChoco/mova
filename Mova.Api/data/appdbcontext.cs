using Microsoft.EntityFrameworkCore;
using Mova.Api.Models;

namespace Mova.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Ride> Rides => Set<Ride>();
    public DbSet<RideRequest> RideRequests => Set<RideRequest>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Ride>()
            .HasOne(r => r.Driver)
            .WithMany()
            .HasForeignKey(r => r.DriverId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<RideRequest>()
            .HasOne(rr => rr.Ride)
            .WithMany()
            .HasForeignKey(rr => rr.RideId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<RideRequest>()
            .HasOne(rr => rr.Passenger)
            .WithMany()
            .HasForeignKey(rr => rr.PassengerId)
            .OnDelete(DeleteBehavior.Restrict);

        // A passenger can only have one active request per ride
        modelBuilder.Entity<RideRequest>()
            .HasIndex(rr => new { rr.RideId, rr.PassengerId })
            .IsUnique();
    }
}