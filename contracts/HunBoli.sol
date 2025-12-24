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
    event Confiscated(address indexed user, uint256 amount);

    // Eventos de Auditoría
    event Minted(address indexed minter, address indexed to, uint256 amount);
    event Burned(address indexed burner, address indexed from, uint256 amount);
    event SystemPaused(address indexed account);
    event SystemUnpaused(address indexed account);
    event AddedToBlacklist(address indexed account, address indexed by);
    event RemovedFromBlacklist(address indexed account, address indexed by);

    constructor(
        address adminAddress,
        uint256 maxSupply
    ) ERC20("HUNBOLI", "BOBH") {
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

    // --- HOOK DE SEGURIDAD (Aquí está el cambio de tu amigo) ---
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        address sender = _msgSender();

        // 1. Verificamos REMITENTE (from)
        if (from != address(0)) {
            // Permitimos mover fondos DE una cuenta blacklist SOLO si es acción del sistema (Confiscar/Finalizar)
            bool isSystemAction = hasRole(BLACKLIST_MANAGER_ROLE, sender) ||
                hasRole(BURNER_ROLE, sender);

            if (!isSystemAction) {
                require(!isBlacklisted[from], "Sender is blacklisted");
            }
        }

        // 2. Verificamos DESTINATARIO (to) - CORRECCIÓN APLICADA
        if (to != address(0)) {
            // Tu amigo sugirió esto: Permitir recibir fondos SOLO si es una devolución del sistema
            // (Es decir: lo hace un Admin Y el dinero viene del propio contrato)
            bool isRefundAction = (hasRole(BURNER_ROLE, sender) ||
                hasRole(BLACKLIST_MANAGER_ROLE, sender)) &&
                from == address(this);

            if (!isRefundAction) {
                // Si NO es una devolución oficial, aplicamos la restricción normal
                require(!isBlacklisted[to], "Recipient is blacklisted");
            }
        }

        super._update(from, to, value);
    }

    // --- MINTING ---
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
        emit Minted(msg.sender, to, amount);
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

    // Esta es la función que fallaba y ahora funcionará
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
        // Ahora _transfer permitirá enviar al usuario aunque esté en blacklist
        // porque `from` es `address(this)` y el sender tiene rol `BURNER_ROLE`
        _transfer(address(this), user, amount);
        emit RedemptionRejected(user, amount);
    }

    // --- CONFISCACIÓN ---
    function confiscate(
        address user
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(isBlacklisted[user], "User is not blacklisted");

        uint256 walletBalance = balanceOf(user);
        uint256 pendingAmount = pendingRedemptions[user];
        uint256 total = walletBalance + pendingAmount;

        if (pendingAmount > 0) {
            pendingRedemptions[user] = 0;
            _burn(address(this), pendingAmount);
        }

        if (walletBalance > 0) {
            _burn(user, walletBalance);
        }

        emit Confiscated(user, total);
        emit Burned(msg.sender, user, total);
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
}
