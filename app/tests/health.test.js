const request = require("supertest");
const app = require("../src/app");

describe("Health Check", () => {
  test("GET /health should return 200 and UP status", async () => {
    const response = await request(app).get("/health");

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      status: "UP",
      service: "task-api"
    });
  });
});
