const express = require("express");
const pool = require("./config/database");

const app = express();

app.use(express.json());

// Test database connection
pool.query("SELECT NOW()", (err, result) => {
    if (err) {
        console.error("Database connection failed:", err);
    } else {
        console.log("Database connected:", result.rows[0]);
    }
});

// Health check
app.get("/health", (req, res) => {
    res.status(200).json({
        status: "UP",
        service: "task-api"
    });
});

const PORT = process.env.PORT || 8080;

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
