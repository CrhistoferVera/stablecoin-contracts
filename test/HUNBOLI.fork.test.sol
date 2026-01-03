// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/HunBoli.sol"; // Ajusta si tu path/nombre es distinto

/// @dev Mock ERC20 mínimo para probar recoverERC20
contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "bal");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "bal");
        uint256 a = allowance[from][msg.sender];
        require(a >= amount, "allow");
        allowance[from][msg.sender] = a - amount;

        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/**
 * @title HUNBOLI Fork Tests (Mejorado)
 * @notice Corre contra el contrato REAL deployado en Sepolia, pero sobre una fork local (no gasta gas real).
 *
 * Requiere .env con:
 *  SEPOLIA_RPC_URL=...
 *  SEPOLIA_DEPLOYED_ADDRESS=0x...
 *  SEPOLIA_ADMIN_ADDRESS=0x...
 * Opcional:
 *  SEPOLIA_FORK_BLOCK=0  (si pones un bloque, se vuelve 100% reproducible)
 */
contract HUNBOLIForkTest is Test {
    MyStableCoin public coin;

    address public deployedAddress;
    address public realAdmin;

    address public user1;
    address public user2;
    address public attacker;

    bytes32 public MINTER_ROLE;
    bytes32 public BURNER_ROLE;
    bytes32 public PAUSER_ROLE;
    bytes32 public BLACKLIST_MANAGER_ROLE;
    bytes32 public DEFAULT_ADMIN_ROLE;

    // ============
    // SETUP
    // ============
    function setUp() public {
        // 1) Crear fork (ya no dependes de --fork-url en CLI)
        string memory rpc = vm.envString("SEPOLIA_RPC_URL");
        uint256 forkBlock = vm.envOr("SEPOLIA_FORK_BLOCK", uint256(0));
        if (forkBlock != 0) vm.createSelectFork(rpc, forkBlock);
        else vm.createSelectFork(rpc);

        // 2) Conectar a contrato real (por env)
        deployedAddress = vm.envAddress("SEPOLIA_DEPLOYED_ADDRESS");
        coin = MyStableCoin(deployedAddress);

        // 3) Admin real (por env) -> sin heurísticas
        realAdmin = vm.envAddress("SEPOLIA_ADMIN_ADDRESS");

        // 4) Roles
        MINTER_ROLE = coin.MINTER_ROLE();
        BURNER_ROLE = coin.BURNER_ROLE();
        PAUSER_ROLE = coin.PAUSER_ROLE();
        BLACKLIST_MANAGER_ROLE = coin.BLACKLIST_MANAGER_ROLE();
        DEFAULT_ADMIN_ROLE = coin.DEFAULT_ADMIN_ROLE();

        // 5) Usuarios
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        attacker = makeAddr("attacker");

        // Validación temprana (si falla aquí, tu .env está mal o el admin no es admin)
        assertTrue(coin.hasRole(DEFAULT_ADMIN_ROLE, realAdmin), "env admin is not DEFAULT_ADMIN_ROLE");

        // Log opcional
        console2.log("=== HUNBOLI FORK TEST ===");
        console2.log("Contract:", deployedAddress);
        console2.log("Admin:", realAdmin);
        console2.log("Supply:", coin.totalSupply());
        console2.log("========================");
    }

    // ============
    // HELPERS
    // ============
    function _ensureUnpaused() internal {
        if (coin.paused()) {
            vm.prank(realAdmin);
            coin.unpause();
        }
    }

    function _ensureNotBlacklisted(address a) internal {
        if (coin.isBlacklisted(a)) {
            vm.prank(realAdmin);
            coin.removeFromBlacklist(a);
        }
    }

    function _mint(address to, uint256 amount) internal {
        _ensureUnpaused();
        _ensureNotBlacklisted(to);
        vm.prank(realAdmin);
        coin.mint(to, amount);
    }

    // ============================================================
    // BASIC / STATE
    // ============================================================
    function test_Fork_ContractExists() public view {
        address addr = deployedAddress;
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        assertTrue(size > 0, "Contract does not exist at address");
    }

    function test_Fork_Metadata() public view {
        assertEq(coin.name(), "HUNBOLI");
        assertEq(coin.symbol(), "BOBH");
        assertEq(coin.decimals(), 6);
        assertTrue(coin.MAX_SUPPLY() > 0);
    }

    function test_Fork_AdminHasAllRoles() public view {
        assertTrue(coin.hasRole(DEFAULT_ADMIN_ROLE, realAdmin));
        assertTrue(coin.hasRole(MINTER_ROLE, realAdmin));
        assertTrue(coin.hasRole(BURNER_ROLE, realAdmin));
        assertTrue(coin.hasRole(PAUSER_ROLE, realAdmin));
        assertTrue(coin.hasRole(BLACKLIST_MANAGER_ROLE, realAdmin));
    }

    // ============================================================
    // PERMISSIONS (NEGATIVE)
    // ============================================================
    function test_Fork_NormalUserCannotMint() public {
        vm.prank(user1);
        vm.expectRevert();
        coin.mint(user1, 1_000_000);
    }

    function test_Fork_NormalUserCannotMintBatch() public {
        address[] memory r = new address[](1);
        r[0] = user1;
        uint256[] memory a = new uint256[](1);
        a[0] = 1_000_000;

        vm.prank(user1);
        vm.expectRevert();
        coin.mintBatch(r, a);
    }

    function test_Fork_NormalUserCannotPauseOrBlacklistOrRecover() public {
        vm.prank(attacker);
        vm.expectRevert();
        coin.pause();

        vm.prank(attacker);
        vm.expectRevert();
        coin.addToBlacklist(user1);

        vm.prank(attacker);
        vm.expectRevert();
        coin.recoverERC20(address(0x1234), attacker, 1);
    }

    // ============================================================
    // MINT / MINTBATCH
    // ============================================================
    function test_Fork_AdminCanMint() public {
        _ensureUnpaused();
        uint256 supplyBefore = coin.totalSupply();
        uint256 balBefore = coin.balanceOf(user1);

        vm.prank(realAdmin);
        coin.mint(user1, 1_000_000);

        assertEq(coin.balanceOf(user1), balBefore + 1_000_000);
        assertEq(coin.totalSupply(), supplyBefore + 1_000_000);
    }

    function test_Fork_Mint_RevertsIfRecipientBlacklisted() public {
        _ensureUnpaused();
        _ensureNotBlacklisted(user1);

        vm.prank(realAdmin);
        coin.addToBlacklist(user1);

        vm.prank(realAdmin);
        vm.expectRevert(bytes("Recipient is blacklisted"));
        coin.mint(user1, 1_000_000);
    }

    function test_Fork_AdminCanMintBatch() public {
        _ensureUnpaused();
        _ensureNotBlacklisted(user1);
        _ensureNotBlacklisted(user2);

        uint256 supplyBefore = coin.totalSupply();
        uint256 maxSupply = coin.MAX_SUPPLY();
        uint256 headroom = maxSupply - supplyBefore;
        require(headroom > 0, "No headroom to mint");

        // Montos que se adapten al headroom
        uint256 a1 = 1_000_000;
        uint256 a2 = 2_000_000;
        if (headroom < a1 + a2) {
            a1 = headroom / 2;
            a2 = headroom - a1;
        }

        address[] memory r = new address[](2);
        r[0] = user1;
        r[1] = user2;

        uint256[] memory a = new uint256[](2);
        a[0] = a1;
        a[1] = a2;

        uint256 b1 = coin.balanceOf(user1);
        uint256 b2 = coin.balanceOf(user2);

        vm.prank(realAdmin);
        coin.mintBatch(r, a);

        assertEq(coin.balanceOf(user1), b1 + a1);
        assertEq(coin.balanceOf(user2), b2 + a2);
        assertEq(coin.totalSupply(), supplyBefore + a1 + a2);
    }

    function test_Fork_MintBatch_RevertsOnLengthMismatch() public {
        address[] memory r = new address[](2);
        r[0] = user1;
        r[1] = user2;

        uint256[] memory a = new uint256[](1);
        a[0] = 1_000_000;

        vm.prank(realAdmin);
        vm.expectRevert(bytes("Arrays length mismatch"));
        coin.mintBatch(r, a);
    }

    function test_Fork_MintBatch_RevertsOnEmptyArrays() public {
        address[] memory r = new address[](0);
        uint256[] memory a = new uint256[](0);

        vm.prank(realAdmin);
        vm.expectRevert(bytes("Empty arrays"));
        coin.mintBatch(r, a);
    }

    function test_Fork_MintBatch_CannotExceedMaxSupply() public {
        uint256 maxSupply = coin.MAX_SUPPLY();
        uint256 supply = coin.totalSupply();

        uint256 excess = (maxSupply - supply) + 1;

        address[] memory r = new address[](1);
        r[0] = user1;

        uint256[] memory a = new uint256[](1);
        a[0] = excess;

        vm.prank(realAdmin);
        vm.expectRevert(bytes("Exceeds maximum supply"));
        coin.mintBatch(r, a);
    }

    // ============================================================
    // ERC20 BEHAVIOR
    // ============================================================
    function test_Fork_TransferBetweenUsers() public {
        _mint(user1, 5_000_000);

        vm.prank(user1);
        coin.transfer(user2, 2_000_000);

        assertEq(coin.balanceOf(user2), 2_000_000);
        assertEq(coin.balanceOf(user1), 3_000_000);
    }

    function test_Fork_ApproveAndTransferFrom() public {
        _mint(user1, 5_000_000);

        vm.prank(user1);
        coin.approve(realAdmin, 2_000_000);

        vm.prank(realAdmin);
        coin.transferFrom(user1, user2, 2_000_000);

        assertEq(coin.balanceOf(user2), 2_000_000);
        assertEq(coin.balanceOf(user1), 3_000_000);
    }

    // ============================================================
    // PAUSE
    // ============================================================
    function test_Fork_PauseBlocksTransferMintAndRedemption() public {
        _ensureUnpaused();

        vm.prank(realAdmin);
        coin.pause();
        assertTrue(coin.paused());

        // Mint bloqueado
        vm.prank(realAdmin);
        vm.expectRevert();
        coin.mint(user1, 1_000_000);

        // Transfer bloqueado
        // (necesitamos balance previo, así que despausamos -> mint -> pausamos)
        vm.prank(realAdmin);
        coin.unpause();
        _mint(user1, 2_000_000);

        vm.prank(realAdmin);
        coin.pause();

        vm.prank(user1);
        vm.expectRevert();
        coin.transfer(user2, 1_000_000);

        // Redemption bloqueada
        vm.prank(user1);
        vm.expectRevert();
        coin.requestRedemption(1_000_000);
    }

    // ============================================================
    // BLACKLIST (BLOCKS + EXCEPTIONS)
    // ============================================================
    function test_Fork_BlacklistBlocksSendAndReceive() public {
        _ensureUnpaused();
        _mint(user1, 5_000_000);

        // block send
        vm.prank(realAdmin);
        coin.addToBlacklist(user1);

        vm.prank(user1);
        vm.expectRevert(bytes("Sender is blacklisted"));
        coin.transfer(user2, 1_000_000);

        // unblock user1, block user2 (block receive)
        vm.prank(realAdmin);
        coin.removeFromBlacklist(user1);

        vm.prank(realAdmin);
        coin.addToBlacklist(user2);

        vm.prank(user1);
        vm.expectRevert(bytes("Recipient is blacklisted"));
        coin.transfer(user2, 1_000_000);
    }

    function test_Fork_SystemActionCanTransferFromBlacklisted() public {
        _ensureUnpaused();
        _mint(user1, 5_000_000);

        // user1 aprueba al admin
        vm.prank(user1);
        coin.approve(realAdmin, 2_000_000);

        // luego lo blacklistean
        vm.prank(realAdmin);
        coin.addToBlacklist(user1);

        // admin (BURNER/BLACKLIST_MANAGER) puede mover fondos DESDE blacklisted
        vm.prank(realAdmin);
        coin.transferFrom(user1, user2, 2_000_000);

        assertEq(coin.balanceOf(user2), 2_000_000);
    }

    // ============================================================
    // REDEMPTION
    // ============================================================
    function test_Fork_RequestRedemption_RevertsIfInsufficientBalance() public {
        _ensureUnpaused();

        vm.prank(user1);
        vm.expectRevert(bytes("Saldo insuficiente"));
        coin.requestRedemption(1_000_000);
    }

    function test_Fork_FinalizeRedemption_HappyPath() public {
        _ensureUnpaused();

        _mint(user1, 10_000_000);

        vm.prank(user1);
        coin.requestRedemption(4_000_000);

        assertEq(coin.pendingRedemptions(user1), 4_000_000);
        assertEq(coin.balanceOf(address(coin)), 4_000_000);

        uint256 supplyBefore = coin.totalSupply();

        vm.prank(realAdmin);
        coin.finalizeRedemption(user1, 4_000_000);

        assertEq(coin.pendingRedemptions(user1), 0);
        assertEq(coin.balanceOf(address(coin)), 0);
        assertEq(coin.totalSupply(), supplyBefore - 4_000_000);
    }

    function test_Fork_RejectRedemption_HappyPath() public {
        _ensureUnpaused();

        _mint(user1, 10_000_000);
        uint256 balAfterMint = coin.balanceOf(user1);

        vm.prank(user1);
        coin.requestRedemption(4_000_000);

        vm.prank(realAdmin);
        coin.rejectRedemption(user1, 4_000_000);

        assertEq(coin.pendingRedemptions(user1), 0);
        assertEq(coin.balanceOf(user1), balAfterMint);
        assertEq(coin.balanceOf(address(coin)), 0);
    }

    function test_Fork_RejectRedemption_WorksEvenIfUserIsBlacklisted() public {
        _ensureUnpaused();

        _mint(user1, 10_000_000);

        vm.prank(user1);
        coin.requestRedemption(4_000_000);

        vm.prank(realAdmin);
        coin.addToBlacklist(user1);

        // Esto prueba tu excepción: refund del sistema a blacklisted (from == address(this))
        vm.prank(realAdmin);
        coin.rejectRedemption(user1, 4_000_000);

        assertEq(coin.pendingRedemptions(user1), 0);
    }

    function test_Fork_FinalizeRedemption_RevertsIfWrongAmount() public {
        _ensureUnpaused();

        _mint(user1, 10_000_000);

        vm.prank(user1);
        coin.requestRedemption(4_000_000);

        vm.prank(realAdmin);
        vm.expectRevert(bytes("Monto incorrecto"));
        coin.finalizeRedemption(user1, 4_000_000 + 1);
    }

    function test_Fork_FinalizeRedemption_RevertsIfNoCustody() public {
        _ensureUnpaused();

        _mint(user1, 10_000_000);

        vm.prank(user1);
        coin.requestRedemption(4_000_000);

        // Drenamos custodia (en mainnet esto no puede pasar “por sí solo”, pero sirve para cubrir rama crítica)
        vm.prank(address(coin));
        coin.transfer(attacker, 4_000_000);

        vm.prank(realAdmin);
        vm.expectRevert(bytes("No hay tokens en custodia"));
        coin.finalizeRedemption(user1, 4_000_000);
    }

    function test_Fork_RejectRedemption_RevertsIfNoCustody() public {
        _ensureUnpaused();

        _mint(user1, 10_000_000);

        vm.prank(user1);
        coin.requestRedemption(4_000_000);

        vm.prank(address(coin));
        coin.transfer(attacker, 4_000_000);

        vm.prank(realAdmin);
        vm.expectRevert(bytes("No hay tokens en custodia"));
        coin.rejectRedemption(user1, 4_000_000);
    }

    // ============================================================
    // CONFISCATE
    // ============================================================
    function test_Fork_Confiscate_RevertsIfNotBlacklisted() public {
        _ensureUnpaused();

        vm.prank(realAdmin);
        vm.expectRevert(bytes("User is not blacklisted"));
        coin.confiscate(user1);
    }

    function test_Fork_Confiscate_WalletAndPending() public {
        _ensureUnpaused();

        // user1 tiene wallet + pending
        _mint(user1, 10_000_000);

        vm.prank(user1);
        coin.requestRedemption(4_000_000);

        // user1 queda con 6M en wallet, 4M en custodia, pending=4M
        assertEq(coin.balanceOf(user1), 6_000_000);
        assertEq(coin.balanceOf(address(coin)), 4_000_000);
        assertEq(coin.pendingRedemptions(user1), 4_000_000);

        uint256 supplyBefore = coin.totalSupply();

        vm.prank(realAdmin);
        coin.addToBlacklist(user1);

        vm.prank(realAdmin);
        coin.confiscate(user1);

        assertEq(coin.pendingRedemptions(user1), 0);
        assertEq(coin.balanceOf(user1), 0);
        assertEq(coin.balanceOf(address(coin)), 0);

        // Se quemó wallet + pending = 10M
        assertEq(coin.totalSupply(), supplyBefore - 10_000_000);
    }

    function test_Fork_Confiscate_RevertsIfCustodyInsufficientForPending() public {
        _ensureUnpaused();

        _mint(user1, 10_000_000);

        vm.prank(user1);
        coin.requestRedemption(4_000_000);

        vm.prank(realAdmin);
        coin.addToBlacklist(user1);

        // Drenamos la custodia para disparar el require
        vm.prank(address(coin));
        coin.transfer(attacker, 4_000_000);

        vm.prank(realAdmin);
        vm.expectRevert(bytes("Contract has insufficient balance for pending redemptions"));
        coin.confiscate(user1);
    }

    // ============================================================
    // RECOVER ERC20
    // ============================================================
    function test_Fork_RecoverERC20_Success() public {
        _ensureUnpaused();

        MockERC20 mock = new MockERC20();
        uint256 amount = 5e18;

        mock.mint(address(this), amount);
        mock.transfer(address(coin), amount);
        assertEq(mock.balanceOf(address(coin)), amount);

        uint256 before = mock.balanceOf(user2);

        vm.prank(realAdmin);
        coin.recoverERC20(address(mock), user2, amount);

        assertEq(mock.balanceOf(address(coin)), 0);
        assertEq(mock.balanceOf(user2), before + amount);
    }

    function test_Fork_RecoverERC20_RevertsOnOwnToken() public {
        vm.prank(realAdmin);
        vm.expectRevert(bytes("Cannot recover own token"));
        coin.recoverERC20(address(coin), user1, 1);
    }

    function test_Fork_RecoverERC20_RevertsOnZeroTo() public {
        MockERC20 mock = new MockERC20();
        vm.prank(realAdmin);
        vm.expectRevert(bytes("Cannot recover to zero address"));
        coin.recoverERC20(address(mock), address(0), 1);
    }

    function test_Fork_RecoverERC20_RevertsOnZeroAmount() public {
        MockERC20 mock = new MockERC20();
        vm.prank(realAdmin);
        vm.expectRevert(bytes("Amount must be greater than zero"));
        coin.recoverERC20(address(mock), user1, 0);
    }

    function test_Fork_RecoverERC20_RevertsOnInsufficientBalance() public {
        MockERC20 mock = new MockERC20();

        vm.prank(realAdmin);
        vm.expectRevert(bytes("Insufficient token balance"));
        coin.recoverERC20(address(mock), user1, 1);
    }

    function test_Fork_NonAdminCannotRecoverERC20() public {
        MockERC20 mock = new MockERC20();
        mock.mint(address(coin), 1e18);

        vm.prank(attacker);
        vm.expectRevert();
        coin.recoverERC20(address(mock), attacker, 1e18);
    }
}
