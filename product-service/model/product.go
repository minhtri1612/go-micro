package model

// Product represents a product entity
type Product struct {
	ID            int     `json:"id"`
	Name          string  `json:"name"`
	Description   string  `json:"description"`
	Price         float64 `json:"price"`
	Category      *string `json:"category,omitempty"`
	ImageURL      *string `json:"image_url,omitempty"`
	StockQuantity *int    `json:"stock_quantity,omitempty"`
	CreatedAt     *string `json:"created_at,omitempty"`
	UpdatedAt     *string `json:"updated_at,omitempty"`
}
