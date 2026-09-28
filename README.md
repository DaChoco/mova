# Mova Backend

This branch contains the backend/API for the Mova carpooling application.

## Technology

- C#
- ASP.NET Core Web API
- AWS
- SQLite
- MongoDB Atlas

## Architecture

The Flutter mobile application communicates with the ASP.NET Core REST API using HTTP and JSON.

The backend is responsible for:

- Authentication
- User management
- Ride management
- Driver management
- Messaging
- Database communication
- External service integration

## Databases

### SQLite

Used for relational application data.

### MongoDB Atlas

Used for chat and messaging data.

## External Services

- Google OAuth — authentication
- Google Maps API — maps, location and routing
- Authenticator 2FA — two-factor authentication
- AWS — backend hosting

## API Documentation

See:

`docs/api-contract.md`

## Development Order

1. Create the ASP.NET Core Web API project
2. Implement authentication
3. Implement users
4. Implement rides
5. Implement drivers
6. Implement messaging
7. Integrate external services
8. Deploy the API to AWS

## Branches

- `main` — main project branch
- `frontend` — Flutter mobile application
- `backend` — C# ASP.NET Core backend/API