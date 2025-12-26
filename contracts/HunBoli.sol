// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract MyStableCoin is ERC20, AccessControl, Pausable {
    // --- ROLES ---
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BLACKLIST_MANAGER_ROLE =
        keccak256("BLACKLIST_MANAGER_ROLE");

    // --- CONFIGURACIÓN ---
    uint256 public immutable MAX_SUPPLY;

    // --- ESTADO ---
    mapping(address => bool) public isBlacklisted;
    mapping(address => uint256) public pendingRedemptions;

    // --- EVENTOS ---
    event RedemptionRequested(address indexed user, uint256 amount);
    event RedemptionFinalized(address indexed user, uint256 amount);
    event RedemptionRejected(address indexed user, uint256 amount);
    event RedemptionCancelled(address indexed user, uint256 amount);
    event Confiscated(address indexed user, uint256 amount);

    // Eventos de Auditoría
    event Minted(address indexed minter, address indexed to, uint256 amount);
    event Burned(address indexed burner, address indexed from, uint256 amount);
    event SystemPaused(address indexed account);
    event SystemUnpaused(address indexed account);
    event AddedToBlacklist(address indexed account, address indexed by);
    event RemovedFromBlacklist(address indexed account, address indexed by);
    event TokensRecovered(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    // MEJORA #2: Validaciones en constructor
    constructor(
        address adminAddress,
        uint256 maxSupply
    ) ERC20("HUNBOLI", "BOBH") {
        require(adminAddress != address(0), "Admin address cannot be zero");
        require(maxSupply > 0, "Max supply must be greater than zero");

        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(MINTER_ROLE, adminAddress);
        _grantRole(BURNER_ROLE, adminAddress);
        _grantRole(PAUSER_ROLE, adminAddress);
        _grantRole(BLACKLIST_MANAGER_ROLE, adminAddress);
        MAX_SUPPLY = maxSupply;
    }

    // 6 Decimales (Requerimiento Cliente)
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // --- GESTIÓN DE LISTA NEGRA ---
    function addToBlacklist(
        address account
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(!isBlacklisted[account], "Account already blacklisted");
        isBlacklisted[account] = true;
        emit AddedToBlacklist(account, msg.sender);
    }

    function removeFromBlacklist(
        address account
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(isBlacklisted[account], "Account not blacklisted");
        isBlacklisted[account] = false;
        emit RemovedFromBlacklist(account, msg.sender);
    }

    // MEJORA #4: Lógica de blacklist simplificada y clara
    // Funciones helper para mejor legibilidad y auditabilidad
    function _isSystemActionFromBlacklisted() internal view returns (bool) {
        // Permite mover fondos DE una cuenta blacklist solo si es acción del sistema
        address sender = _msgSender();
        return
            hasRole(BLACKLIST_MANAGER_ROLE, sender) ||
            hasRole(BURNER_ROLE, sender);
    }

    function _isSystemRefundToBlacklisted(
        address from
    ) internal view returns (bool) {
        // Permite recibir fondos SOLO si es una devolución del sistema
        // (lo hace un Admin Y el dinero viene del propio contrato)
        address sender = _msgSender();
        return
            (hasRole(BURNER_ROLE, sender) ||
                hasRole(BLACKLIST_MANAGER_ROLE, sender)) &&
            from == address(this);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        // 1. Verificar el REMITENTE (from)
        if (from != address(0) && isBlacklisted[from]) {
            require(_isSystemActionFromBlacklisted(), "Sender is blacklisted");
        }

        // 2. Verificar el DESTINATARIO (to)
        if (to != address(0) && isBlacklisted[to]) {
            require(
                _isSystemRefundToBlacklisted(from),
                "Recipient is blacklisted"
            );
        }

        super._update(from, to, value);
    }

    // --- MINTING ---
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
        emit Minted(msg.sender, to, amount);
    }

    // MEJORA: Mint en batch para ahorrar gas
    function mintBatch(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length > 0, "Empty arrays");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(
            totalSupply() + totalAmount <= MAX_SUPPLY,
            "Exceeds maximum supply"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
            emit Minted(msg.sender, recipients[i], amounts[i]);
        }
    }

    // --- REDEMPTION FLOW ---
    function requestRedemption(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Saldo insuficiente");
        pendingRedemptions[msg.sender] += amount;
        _transfer(msg.sender, address(this), amount);
        emit RedemptionRequested(msg.sender, amount);
    }

    function finalizeRedemption(
        address user,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) {
        require(pendingRedemptions[user] >= amount, "Monto incorrecto");
        require(
            balanceOf(address(this)) >= amount,
            "No hay tokens en custodia"
        );

        pendingRedemptions[user] -= amount;
        _burn(address(this), amount);

        emit RedemptionFinalized(user, amount);
        emit Burned(msg.sender, user, amount);
    }

    function rejectRedemption(
        address user,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) {
        require(pendingRedemptions[user] >= amount, "Monto incorrecto");
        require(
            balanceOf(address(this)) >= amount,
            "No hay tokens en custodia"
        );

        pendingRedemptions[user] -= amount;
        _transfer(address(this), user, amount);
        emit RedemptionRejected(user, amount);
    }

    // MEJORA: Permitir al usuario cancelar su propia redemption
    function cancelRedemption(uint256 amount) external {
        require(
            pendingRedemptions[msg.sender] >= amount,
            "Insufficient pending redemption"
        );
        require(
            balanceOf(address(this)) >= amount,
            "No hay tokens en custodia"
        );

        pendingRedemptions[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount);
        emit RedemptionCancelled(msg.sender, amount);
    }

    // MEJORA #1: Confiscación segura con validaciones correctas
    function confiscate(
        address user
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(isBlacklisted[user], "User is not blacklisted");

        uint256 walletBalance = balanceOf(user);
        uint256 pendingAmount = pendingRedemptions[user];
        uint256 contractBalance = balanceOf(address(this));

        // Confiscar fondos pendientes (solo si el contrato tiene suficientes tokens)
        if (pendingAmount > 0) {
            // CRÍTICO: Verificar que el contrato tiene suficientes tokens antes de quemar
            require(
                contractBalance >= pendingAmount,
                "Contract has insufficient balance for pending redemptions"
            );

            pendingRedemptions[user] = 0;
            _burn(address(this), pendingAmount);
        }

        // Confiscar fondos en la wallet
        if (walletBalance > 0) {
            _burn(user, walletBalance);
        }

        uint256 totalConfiscated = walletBalance + pendingAmount;
        emit Confiscated(user, totalConfiscated);
        emit Burned(msg.sender, user, totalConfiscated);
    }

    // --- PAUSA ---
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit SystemPaused(msg.sender);
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
        emit SystemUnpaused(msg.sender);
    }

    // MEJORA: Recuperación de tokens ERC20 enviados por error
    function recoverERC20(
        address tokenAddress,
        address to,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenAddress != address(this), "Cannot recover own token");
        require(to != address(0), "Cannot recover to zero address");
        require(amount > 0, "Amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Insufficient token balance");

        bool success = token.transfer(to, amount);
        require(success, "Token transfer failed");

        emit TokensRecovered(tokenAddress, to, amount);
    }
}
