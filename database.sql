CREATE TABLE
    IF NOT EXISTS mri_qfarm (
        farmId BIGINT AUTO_INCREMENT PRIMARY KEY,
        farmName VARCHAR(100) NOT NULL UNIQUE,
        farmConfig LONGTEXT NULL,
        farmGroup LONGTEXT NULL
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_general_ci;
