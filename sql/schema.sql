DROP TABLE IF EXISTS fact_sales, dim_date, dim_location, dim_product, dim_customer CASCADE;

CREATE TABLE dim_customer (
    customer_key  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   VARCHAR(20)  NOT NULL UNIQUE,
    customer_name VARCHAR(100) NOT NULL,
    segment       VARCHAR(20)  NOT NULL
);

CREATE TABLE dim_product (
    product_key   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id    VARCHAR(20)  NOT NULL UNIQUE,
    product_name  VARCHAR(255) NOT NULL,
    category      VARCHAR(50)  NOT NULL,
    sub_category  VARCHAR(50)  NOT NULL
);

CREATE TABLE dim_location (
    location_key INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country      VARCHAR(50)  NOT NULL,
    region       VARCHAR(20)  NOT NULL,
    state        VARCHAR(50)  NOT NULL,
    city         VARCHAR(100) NOT NULL,
    postal_code  CHAR(5)      NOT NULL,
    UNIQUE (postal_code, city, state, region)
);

CREATE TABLE dim_date (
    date_key    INT PRIMARY KEY,          -- format YYYYMMDD, e.g. 20170811
    full_date   DATE        NOT NULL UNIQUE,
    year        SMALLINT    NOT NULL,
    quarter     SMALLINT    NOT NULL,
    month       SMALLINT    NOT NULL,
    month_name  VARCHAR(10) NOT NULL,
    day         SMALLINT    NOT NULL,
    day_name    VARCHAR(10) NOT NULL
);

CREATE TABLE fact_sales (
    sales_key      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    row_id         INT           NOT NULL UNIQUE,  -- original Row ID from the CSV
    order_id       VARCHAR(20)   NOT NULL,
    order_date_key INT           NOT NULL REFERENCES dim_date(date_key),
    ship_date_key  INT           NOT NULL REFERENCES dim_date(date_key),
    customer_key   INT           NOT NULL REFERENCES dim_customer(customer_key),
    product_key    INT           NOT NULL REFERENCES dim_product(product_key),
    location_key   INT           NOT NULL REFERENCES dim_location(location_key),
    ship_mode      VARCHAR(20)   NOT NULL,
    sales          NUMERIC(12,4) NOT NULL
);

CREATE INDEX idx_fact_order_id ON fact_sales(order_id);
