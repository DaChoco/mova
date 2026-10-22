# Mova API Contract

This document defines the API endpoints used by the Mova mobile application.

## Base API

The API will be implemented using:

- C#
- ASP.NET Core Web API
- Hosted on AWS

The Flutter mobile application communicates with the API using HTTP requests and JSON.

---

# Authentication

## POST /api/auth/register

Registers a new Mova user.

Request and response structure to be defined by the backend team.

---

## POST /api/auth/login

Authenticates an existing Mova user.

Request and response structure to be defined by the backend team.

---

# Users

## GET /api/user/{id}

Retrieves information about a user.

### Request

Token/authentication information is required.

### Response

```json
{
  "success": true,
  "user": {
    "userId": 1,
    "studentNumber": "EDUV1234567",
    "firstName": "John",
    "surname": "Smith",
    "profileicon": "sisisisi.jpg",
    "carId": "1"
  }
}