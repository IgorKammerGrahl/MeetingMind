package middleware

import "github.com/gin-gonic/gin"

// CORS is a permissive CORS middleware suitable for local mobile development.
// ponytail: wide-open origins for the MVP; lock down before any public deploy.
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}
