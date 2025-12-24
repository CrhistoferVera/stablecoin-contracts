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
    // --- EVENTOS DE NEGOCIO (Dashboard) ---
    event RedemptionRequested(address indexed user, uint256 amount);
    event RedemptionFinalized(address indexed user, uint256 amount);
    event RedemptionRejected(address indexed user, uint256 amount);
    event Confiscated(address indexed user, uint256 amount);

    // --- EVENTOS DE AUDITORÍA (Lo que te pidieron) ---
    // Registra QUIÉN ejecutó la acción (minter/burner) y para QUIÉN (to/from)
    event Minted(address indexed minter, address indexed to, uint256 amount);
    event Burned(address indexed burner, address indexed from, uint256 amount);
    // OpenZeppelin ya tiene Paused/Unpaused, pero agregamos estos para ser explícitos
    event SystemPaused(address indexed account);
    event SystemUnpaused(address indexed account);

    // --- EVENTOS DE SEGURIDAD ---
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

    // Usamos 6 decimales por requerimiento del cliente
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // --- GESTIÓN DE LISTA NEGRA ---

    function addToBlacklist(
        address account
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(!isBlacklisted[account], "Account already blacklisted");
        isBlacklisted[account] = true;
        // Agregamos msg.sender para saber QUÉ admin lo bloqueó
        emit AddedToBlacklist(account, msg.sender);
    }

    function removeFromBlacklist(
        address account
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(isBlacklisted[account], "Account not blacklisted");
        isBlacklisted[account] = false;
        emit RemovedFromBlacklist(account, msg.sender);
    }

    // --- HOOK DE SEGURIDAD (Override _update) ---
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        address sender = _msgSender();

        // 1. Verificamos REMITENTE (from)
        if (from != address(0)) {
            // Permitimos mover fondos de blacklist SOLO si es una acción administrativa
            bool isSystemAction = hasRole(BLACKLIST_MANAGER_ROLE, sender) ||
                hasRole(BURNER_ROLE, sender);

            if (!isSystemAction) {
                require(!isBlacklisted[from], "Sender is blacklisted");
            }
        }

        // 2. Verificamos DESTINATARIO (to)
        if (to != address(0)) {
            require(!isBlacklisted[to], "Recipient is blacklisted");
        }

        super._update(from, to, value);
    }

    // --- MINTING (Con evento de auditoría) ---

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(to, amount);
        // AUDITORÍA: Registramos que msg.sender (el Admin) creó tokens
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
        _burn(address(this), amount); // Quema los tokens del contrato

        emit RedemptionFinalized(user, amount);
        // AUDITORÍA: Registramos explícitamente la quema
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
        // AUDITORÍA: Registramos quién confiscó
        emit Burned(msg.sender, user, total);
    }

    // --- PAUSA (Con eventos explícitos) ---
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit SystemPaused(msg.sender); // Evento extra para auditoría clara
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
        emit SystemUnpaused(msg.sender);
    }
}
