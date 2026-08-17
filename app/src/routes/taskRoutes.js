const express = require("express");
const pool = require("../config/database");

const router = express.Router();

// Create a task
router.post("/tasks", async (req, res) => {
    try {
        const { title, description } = req.body;

        const result = await pool.query(
            `INSERT INTO tasks (title, description)
             VALUES ($1, $2)
             RETURNING *`,
            [title, description]
        );

        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error("Error creating task:", error);
        res.status(500).json({
            error: "Failed to create task"
        });
    }
});

// Get all tasks
router.get("/tasks", async (req, res) => {
    try {
        const result = await pool.query(
            "SELECT * FROM tasks ORDER BY id"
        );

        res.status(200).json(result.rows);
    } catch (error) {
        console.error("Error fetching tasks:", error);
        res.status(500).json({
            error: "Failed to fetch tasks"
        });
    }
});

// Get a single task
router.get("/tasks/:id", async (req, res) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            "SELECT * FROM tasks WHERE id = $1",
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                error: "Task not found"
            });
        }

        res.status(200).json(result.rows[0]);
    } catch (error) {
        console.error("Error fetching task:", error);
        res.status(500).json({
            error: "Failed to fetch task"
        });
    }
});
// Update a task
router.put("/tasks/:id", async (req, res) => {
    try {
        const { id } = req.params;
        const { title, description, status } = req.body;

        const result = await pool.query(
            `UPDATE tasks
             SET title = $1,
                 description = $2,
                 status = $3,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $4
             RETURNING *`,
            [title, description, status, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                error: "Task not found"
            });
        }

        res.status(200).json(result.rows[0]);
    } catch (error) {
        console.error("Error updating task:", error);
        res.status(500).json({
            error: "Failed to update task"
        });
    }
});
// Delete a task
router.delete("/tasks/:id", async (req, res) => {
    try {
        const { id } = req.params;

        const result = await pool.query(
            "DELETE FROM tasks WHERE id = $1 RETURNING *",
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                error: "Task not found"
            });
        }

        res.status(200).json({
            message: "Task deleted successfully",
            task: result.rows[0]
        });
    } catch (error) {
        console.error("Error deleting task:", error);
        res.status(500).json({
            error: "Failed to delete task"
        });
    }
});
module.exports = router;
