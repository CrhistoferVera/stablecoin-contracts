// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract MyStableCoin is ERC20, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ROL DE CUMPLIMIENTO: Quien maneja la lista negra (puede ser el Operador o Multisig)
    bytes32 public constant BLACKLIST_MANAGER_ROLE =
        keccak256("BLACKLIST_MANAGER_ROLE");

    // MAPPING DE LA LISTA NEGRA
    mapping(address => bool) public isBlacklisted;

    event RedemptionRequested(address indexed user, uint256 amount);
    event RedemptionFinalized(address indexed user, uint256 amount);
    event RedemptionRejected(address indexed user, uint256 amount);

    // Eventos de seguridad
    event AddedToBlacklist(address indexed account);
    event RemovedFromBlacklist(address indexed account);

    constructor(address adminAddress) ERC20("HUNBOLI", "BOBH") {
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(MINTER_ROLE, adminAddress);
        _grantRole(BURNER_ROLE, adminAddress);
        _grantRole(PAUSER_ROLE, adminAddress);
        _grantRole(BLACKLIST_MANAGER_ROLE, adminAddress);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // --- GESTIÓN DE LISTA NEGRA ---

    function addToBlacklist(
        address account
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(!isBlacklisted[account], "Account already blacklisted");
        isBlacklisted[account] = true;
        emit AddedToBlacklist(account);
    }

    function removeFromBlacklist(
        address account
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(isBlacklisted[account], "Account not blacklisted");
        isBlacklisted[account] = false;
        emit RemovedFromBlacklist(account);
    }

    // --- EL "POLICÍA" DEL CONTRATO (Override de OpenZeppelin) ---
    // Esta función se ejecuta AUTOMÁTICAMENTE antes de cualquier mint, burn o transfer.
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        // 1. Verificamos si el remitente está en lista negra (si no es minting)
        if (from != address(0)) {
            require(!isBlacklisted[from], "Sender is blacklisted");
        }
        // 2. Verificamos si el destinatario está en lista negra (si no es burning)
        if (to != address(0)) {
            require(!isBlacklisted[to], "Recipient is blacklisted");
        }

        super._update(from, to, value);
    }

    // --- OPERACIONES ---

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function requestRedemption(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Saldo insuficiente");
        // Nota: Si el usuario está en blacklist, _update fallará aquí y no podrá pedir redención
        _transfer(msg.sender, address(this), amount);
        emit RedemptionRequested(msg.sender, amount);
    }

    function finalizeRedemption(
        address user,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) {
        require(
            balanceOf(address(this)) >= amount,
            "No hay tokens en custodia"
        );
        _burn(address(this), amount);
        emit RedemptionFinalized(user, amount);
    }

    function rejectRedemption(
        address user,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) {
        require(
            balanceOf(address(this)) >= amount,
            "No hay tokens en custodia"
        );
        // Nota: Si el usuario fue puesto en blacklist MIENTRAS esperaba,
        // esta función fallará y los tokens se quedarán atrapados en el contrato (lo cual es correcto en compliance)
        _transfer(address(this), user, amount);
        emit RedemptionRejected(user, amount);
    }

    // --- PAUSA DE EMERGENCIA ---
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
