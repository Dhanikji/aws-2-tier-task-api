const express = require("express");
const taskRoutes = require("./routes/taskRoutes");

const app = express();

app.use(express.json());
app.use("/api", taskRoutes);

// Health check
app.get("/health", (req, res) => {
    res.status(200).json({
        status: "UP",
        service: "task-api"
    });
});

module.exports = app;
