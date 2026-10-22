using Microsoft.Extensions.Options;
using MongoDB.Driver;
using Mova.Api.Models;

namespace Mova.Api.Data;

public class MongoDbContext
{
    private readonly IMongoDatabase _database;

    // Constructor that initializes the MongoDB context using the provided settings.
    public MongoDbContext(IOptions<MongoSettings> settings)
    {
        var client = new MongoClient(settings.Value.ConnectionString);
        _database = client.GetDatabase(settings.Value.DatabaseName);
    }

    public IMongoCollection<MessageDocument> Messages =>
        _database.GetCollection<MessageDocument>("messages");
}