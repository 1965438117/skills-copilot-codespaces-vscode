-- 银行管理系统数据库设计 (MySQL)
-- 包含三张表：用户信息表、交易流水表、操作日志表
-- 以及相关的存储过程和触发器

-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS grouponep CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 使用数据库
USE grouponep;

-- 删除已存在的表（如果存在）
DROP TABLE IF EXISTS operation_logs;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS users;

-- 创建用户表
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    id_number VARCHAR(18) NOT NULL UNIQUE,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    status ENUM('active', 'locked', 'closed') NOT NULL DEFAULT 'active',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_id_number (id_number),
    INDEX idx_status (status)
) ENGINE=InnoDB;

-- 创建交易流水表
CREATE TABLE transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    transaction_type ENUM('deposit', 'withdraw', 'transfer_in', 'transfer_out') NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    balance_before DECIMAL(15, 2) NOT NULL,
    balance_after DECIMAL(15, 2) NOT NULL,
    related_user_id INT NULL,
    transaction_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('success', 'failed') NOT NULL DEFAULT 'success',
    remarks VARCHAR(255) NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_transaction_time (transaction_time),
    INDEX idx_transaction_type (transaction_type),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- 创建操作日志表
CREATE TABLE operation_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    operation_type VARCHAR(50) NOT NULL,
    operation_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    operation_details JSON NULL,
    ip_address VARCHAR(50) NULL,
    status ENUM('success', 'failed') NOT NULL DEFAULT 'success',
    error_message VARCHAR(255) NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_operation_time (operation_time),
    INDEX idx_operation_type (operation_type),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- 存储过程：创建用户
DELIMITER //
CREATE PROCEDURE sp_create_user(
    IN p_username VARCHAR(50),
    IN p_password_hash VARCHAR(255),
    IN p_id_number VARCHAR(18),
    IN p_initial_balance DECIMAL(15, 2),
    IN p_ip_address VARCHAR(50),
    OUT p_user_id INT,
    OUT p_status BOOLEAN,
    OUT p_message VARCHAR(255)
)
sp_label: BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = FALSE;
        SET p_message = 'Database error occurred';
        SET p_user_id = 0;
    END;

    -- 验证输入
    IF p_initial_balance < 0 THEN
        SET p_status = FALSE;
        SET p_message = 'Initial balance cannot be negative';
        SET p_user_id = 0;
        LEAVE sp_label;
    END IF;

    -- 检查身份证号是否已存在
    IF EXISTS (SELECT 1 FROM users WHERE id_number = p_id_number) THEN
        SET p_status = FALSE;
        SET p_message = 'ID number already exists';
        SET p_user_id = 0;
        LEAVE sp_label;
    END IF;

    START TRANSACTION;

    -- 插入用户记录
    INSERT INTO users (username, password_hash, id_number, balance, status)
    VALUES (p_username, p_password_hash, p_id_number, p_initial_balance, 'active');

    -- 获取新用户ID
    SET p_user_id = LAST_INSERT_ID();

    -- 如果有初始存款，记录交易
    IF p_initial_balance > 0 THEN
        INSERT INTO transactions (
            user_id, 
            transaction_type, 
            amount, 
            balance_before, 
            balance_after, 
            transaction_time, 
            status, 
            remarks
        )
        VALUES (
            p_user_id, 
            'deposit', 
            p_initial_balance, 
            0, 
            p_initial_balance, 
            NOW(), 
            'success', 
            'Initial deposit'
        );
    END IF;

    -- 记录操作日志
    INSERT INTO operation_logs (
        user_id, 
        operation_type, 
        operation_details, 
        ip_address, 
        status
    )
    VALUES (
        p_user_id, 
        'create_user', 
        JSON_OBJECT(
            'username', p_username,
            'id_number', p_id_number,
            'initial_balance', p_initial_balance
        ), 
        p_ip_address, 
        'success'
    );

    COMMIT;

    SET p_status = TRUE;
    SET p_message = 'User created successfully';
END //
DELIMITER ;

-- 存储过程：存款
DELIMITER //
CREATE PROCEDURE sp_deposit(
    IN p_user_id INT,
    IN p_amount DECIMAL(15, 2),
    IN p_ip_address VARCHAR(50),
    OUT p_status BOOLEAN,
    OUT p_message VARCHAR(255)
)
sp_label: BEGIN
    DECLARE current_balance DECIMAL(15, 2);
    DECLARE user_status VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = FALSE;
        SET p_message = 'Database error occurred';
    END;

    -- 验证输入
    IF p_amount <= 0 THEN
        SET p_status = FALSE;
        SET p_message = 'Deposit amount must be positive';
        LEAVE sp_label;
    END IF;

    START TRANSACTION;

    -- 检查账户是否存在且状态正常
    SELECT balance, status INTO current_balance, user_status 
    FROM users 
    WHERE user_id = p_user_id 
    FOR UPDATE;

    IF current_balance IS NULL THEN
        SET p_status = FALSE;
        SET p_message = 'User not found';
        ROLLBACK;
        LEAVE sp_label;
    END IF;

    IF user_status != 'active' THEN
        SET p_status = FALSE;
        SET p_message = CONCAT('Account is ', user_status);
        ROLLBACK;
        LEAVE sp_label;
    END IF;

    -- 更新余额
    UPDATE users 
    SET balance = balance + p_amount 
    WHERE user_id = p_user_id;

    -- 记录交易
    INSERT INTO transactions (
        user_id, 
        transaction_type, 
        amount, 
        balance_before, 
        balance_after, 
        transaction_time, 
        status, 
        remarks
    )
    VALUES (
        p_user_id, 
        'deposit', 
        p_amount, 
        current_balance, 
        current_balance + p_amount, 
        NOW(), 
        'success', 
        'Deposit transaction'
    );

    -- 记录操作日志
    INSERT INTO operation_logs (
        user_id, 
        operation_type, 
        operation_details, 
        ip_address, 
        status
    )
    VALUES (
        p_user_id, 
        'deposit', 
        JSON_OBJECT(
            'amount', p_amount,
            'balance_before', current_balance,
            'balance_after', current_balance + p_amount
        ), 
        p_ip_address, 
        'success'
    );

    COMMIT;

    SET p_status = TRUE;
    SET p_message = 'Deposit successful';
END //
DELIMITER ;

-- 存储过程：取款
DELIMITER //
CREATE PROCEDURE sp_withdraw(
    IN p_user_id INT,
    IN p_amount DECIMAL(15, 2),
    IN p_ip_address VARCHAR(50),
    OUT p_status BOOLEAN,
    OUT p_message VARCHAR(255)
)
sp_label: BEGIN
    DECLARE current_balance DECIMAL(15, 2);
    DECLARE user_status VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = FALSE;
        SET p_message = 'Database error occurred';
    END;

    -- 验证输入
    IF p_amount <= 0 THEN
        SET p_status = FALSE;
        SET p_message = 'Withdrawal amount must be positive';
        LEAVE sp_label;
    END IF;

    START TRANSACTION;

    -- 检查账户是否存在且状态正常
    SELECT balance, status INTO current_balance, user_status 
    FROM users 
    WHERE user_id = p_user_id 
    FOR UPDATE;

    IF current_balance IS NULL THEN
        SET p_status = FALSE;
        SET p_message = 'User not found';
        ROLLBACK;
        LEAVE sp_label;
    END IF;

    IF user_status != 'active' THEN
        SET p_status = FALSE;
        SET p_message = CONCAT('Account is ', user_status);
        ROLLBACK;
        LEAVE sp_label;
    END IF;

    -- 检查余额是否足够
    IF current_balance < p_amount THEN
        SET p_status = FALSE;
        SET p_message = 'Insufficient balance';

        -- 记录失败的操作日志
        INSERT INTO operation_logs (
            user_id, 
            operation_type, 
            operation_details, 
            ip_address, 
            status, 
            error_message
        )
        VALUES (
            p_user_id, 
            'withdraw', 
            JSON_OBJECT(
                'amount', p_amount,
                'balance', current_balance
            ), 
            p_ip_address, 
            'failed',
            'Insufficient balance'
        );

        ROLLBACK;
        LEAVE sp_label;
    END IF;

    -- 更新余额
    UPDATE users 
    SET balance = balance - p_amount 
    WHERE user_id = p_user_id;

    -- 记录交易
    INSERT INTO transactions (
        user_id, 
        transaction_type, 
        amount, 
        balance_before, 
        balance_after, 
        transaction_time, 
        status, 
        remarks
    )
    VALUES (
        p_user_id, 
        'withdraw', 
        p_amount, 
        current_balance, 
        current_balance - p_amount, 
        NOW(), 
        'success', 
        'Withdrawal transaction'
    );

    -- 记录操作日志
    INSERT INTO operation_logs (
        user_id, 
        operation_type, 
        operation_details, 
        ip_address, 
        status
    )
    VALUES (
        p_user_id, 
        'withdraw', 
        JSON_OBJECT(
            'amount', p_amount,
            'balance_before', current_balance,
            'balance_after', current_balance - p_amount
        ), 
        p_ip_address, 
        'success'
    );

    COMMIT;

    SET p_status = TRUE;
    SET p_message = 'Withdrawal successful';
END //
DELIMITER ;

-- 存储过程：转账
DELIMITER //
CREATE PROCEDURE sp_transfer(
    IN p_from_user_id INT,
    IN p_to_user_id INT,
    IN p_amount DECIMAL(15, 2),
    IN p_ip_address VARCHAR(50),
    OUT p_status BOOLEAN,
    OUT p_message VARCHAR(255)
)
sp_label: BEGIN
    DECLARE from_balance DECIMAL(15, 2);
    DECLARE to_balance DECIMAL(15, 2);
    DECLARE from_status VARCHAR(10);
    DECLARE to_status VARCHAR(10);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = FALSE;
        SET p_message = 'Database error occurred';
    END;

    -- 验证输入
    IF p_amount <= 0 THEN
        SET p_status = FALSE;
        SET p_message = 'Transfer amount must be positive';
        LEAVE sp_label;
    END IF;

    IF p_from_user_id = p_to_user_id THEN
        SET p_status = FALSE;
        SET p_message = 'Cannot transfer to the same account';
        LEAVE sp_label;
    END IF;

    START TRANSACTION;

    -- 检查转出账户是否存在且状态正常
    SELECT balance, status INTO from_balance, from_status 
    FROM users 
    WHERE user_id = p_from_user_id 
    FOR UPDATE;

    IF from_balance IS NULL THEN
        SET p_status = FALSE;
        SET p_message = 'Source account not found';
        ROLLBACK;
        LEAVE sp_label;
    END IF;

    IF from_status != 'active' THEN
        SET p_status = FALSE;
        SET p_message = CONCAT('Source account is ', from_status);
        ROLLBACK;
        LEAVE sp_label;
    END IF;

    -- 检查转入账户是否存在且状态正常
    SELECT balance, status INTO to_balance, to_status 
    FROM users 
    WHERE user_id = p_to_user_id 
    FOR UPDATE;

    IF to_balance IS NULL THEN
        SET p_status = FALSE;
        SET p_message = 'Target account not found';
        ROLLBACK;
        LEAVE sp_label;
    END IF;

    IF to_status != 'active' THEN
        SET p_status = FALSE;
        SET p_message = CONCAT('Target account is ', to_status);
        ROLLBACK;
        LEAVE sp_label;
    END IF;

    -- 检查余额是否足够
    IF from_balance < p_amount THEN
        SET p_status = FALSE;
        SET p_message = 'Insufficient balance';

        -- 记录失败的操作日志
        INSERT INTO operation_logs (
            user_id, 
            operation_type, 
            operation_details, 
            ip_address, 
            status, 
            error_message
        )
        VALUES (
            p_from_user_id, 
            'transfer_out', 
            JSON_OBJECT(
                'amount', p_amount,
                'to_user_id', p_to_user_id,
                'balance', from_balance
            ), 
            p_ip_address, 
            'failed',
            'Insufficient balance'
        );

        ROLLBACK;
        LEAVE sp_label;
    END IF;

    -- 更新转出账户余额
    UPDATE users 
    SET balance = balance - p_amount 
    WHERE user_id = p_from_user_id;

    -- 更新转入账户余额
    UPDATE users 
    SET balance = balance + p_amount 
    WHERE user_id = p_to_user_id;

    -- 记录转出交易
    INSERT INTO transactions (
        user_id, 
        transaction_type, 
        amount, 
        balance_before, 
        balance_after, 
        related_user_id,
        transaction_time, 
        status, 
        remarks
    )
    VALUES (
        p_from_user_id, 
        'transfer_out', 
        p_amount, 
        from_balance, 
        from_balance - p_amount, 
        p_to_user_id,
        NOW(), 
        'success', 
        CONCAT('Transfer to user ', p_to_user_id)
    );

    -- 记录转入交易
    INSERT INTO transactions (
        user_id, 
        transaction_type, 
        amount, 
        balance_before, 
        balance_after, 
        related_user_id,
        transaction_time, 
        status, 
        remarks
    )
    VALUES (
        p_to_user_id, 
        'transfer_in', 
        p_amount, 
        to_balance, 
        to_balance + p_amount, 
        p_from_user_id,
        NOW(), 
        'success', 
        CONCAT('Transfer from user ', p_from_user_id)
    );

    -- 记录转出操作日志
    INSERT INTO operation_logs (
        user_id, 
        operation_type, 
        operation_details, 
        ip_address, 
        status
    )
    VALUES (
        p_from_user_id, 
        'transfer_out', 
        JSON_OBJECT(
            'amount', p_amount,
            'to_user_id', p_to_user_id,
            'balance_before', from_balance,
            'balance_after', from_balance - p_amount
        ), 
        p_ip_address, 
        'success'
    );

    -- 记录转入操作日志
    INSERT INTO operation_logs (
        user_id, 
        operation_type, 
        operation_details, 
        ip_address, 
        status
    )
    VALUES (
        p_to_user_id, 
        'transfer_in', 
        JSON_OBJECT(
            'amount', p_amount,
            'from_user_id', p_from_user_id,
            'balance_before', to_balance,
            'balance_after', to_balance + p_amount
        ), 
        p_ip_address, 
        'success'
    );

    COMMIT;

    SET p_status = TRUE;
    SET p_message = 'Transfer successful';
END //
DELIMITER ;

-- 触发器：大额交易警报
DELIMITER //
CREATE TRIGGER trg_large_transaction_alert
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    DECLARE threshold DECIMAL(15, 2) DEFAULT 10000.00;

    IF NEW.amount >= threshold THEN
        INSERT INTO operation_logs (
            user_id, 
            operation_type, 
            operation_details, 
            status
        )
        VALUES (
            NEW.user_id, 
            'large_transaction_alert', 
            JSON_OBJECT(
                'transaction_id', NEW.transaction_id,
                'transaction_type', NEW.transaction_type,
                'amount', NEW.amount,
                'threshold', threshold
            ), 
            'success'
        );
    END IF;
END //
DELIMITER ;

-- 触发器：用户状态变更记录
DELIMITER //
CREATE TRIGGER trg_user_status_change
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO operation_logs (
            user_id, 
            operation_type, 
            operation_details, 
            status
        )
        VALUES (
            NEW.user_id, 
            'status_change', 
            JSON_OBJECT(
                'old_status', OLD.status,
                'new_status', NEW.status
            ), 
            'success'
        );
    END IF;
END //
DELIMITER ;

-- 触发器：防止用户直接删除
DELIMITER //
CREATE TRIGGER trg_prevent_user_delete
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Direct user deletion not allowed. Use status update instead.';
END //
DELIMITER ;

-- 创建初始管理员账号
INSERT INTO users (user_id, username, password_hash, id_number, balance, status)
VALUES (1, '管理员', 'pbkdf2:sha256:260000$rTY6abcd$1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7a8b9c0d', '110101199001011234', 10000.00, 'active');

-- 记录初始管理员账号创建日志
INSERT INTO operation_logs (user_id, operation_type, operation_details, status)
VALUES (1, 'system_init', JSON_OBJECT('message', 'Initial admin account created'), 'success');

-- 记录初始存款交易
INSERT INTO transactions (user_id, transaction_type, amount, balance_before, balance_after, status, remarks)
VALUES (1, 'deposit', 10000.00, 0.00, 10000.00, 'success', 'Initial system deposit');