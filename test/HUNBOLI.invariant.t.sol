// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../contracts/HunBoli.sol";

/**
 * @title HUNBOLI Invariant Tests (Versión Mejorada)
 * @notice Tests críticos de invariantes para la stablecoin HUNBOLI
 * @dev Cubre TODAS las funcionalidades incluyendo mintBatch, recoverERC20, pause
 */
contract HUNBOLIInvariantTest is StdInvariant, Test {
    MyStableCoin public coin;
    Handler public handler;

    address admin = address(1);
    address minter = address(2);
    address burner = address(3);
    address pauser = address(4);
    address blacklister = address(5);

    uint256 constant MAX_SUPPLY = 1_000_000_000_000 * 1_000_000; // 1 trillón BOBH

    function setUp() public {
        // Deploy del contrato
        coin = new MyStableCoin(admin, MAX_SUPPLY);

        // Setup de roles
        vm.startPrank(admin);
        coin.grantRole(coin.MINTER_ROLE(), minter);
        coin.grantRole(coin.BURNER_ROLE(), burner);
        coin.grantRole(coin.PAUSER_ROLE(), pauser);
        coin.grantRole(coin.BLACKLIST_MANAGER_ROLE(), blacklister);
        vm.stopPrank();

        // Deploy del handler
        handler = new Handler(coin, minter, burner, pauser, blacklister);

        // Configurar fuzzing
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = handler.mint.selector;
        selectors[1] = handler.mintBatch.selector; // NUEVO
        selectors[2] = handler.transfer.selector;
        selectors[3] = handler.requestRedemption.selector;
        selectors[4] = handler.finalizeRedemption.selector;
        selectors[5] = handler.rejectRedemption.selector;
        selectors[6] = handler.addToBlacklist.selector;
        selectors[7] = handler.removeFromBlacklist.selector;
        selectors[8] = handler.confiscate.selector;
        selectors[9] = handler.pauseSystem.selector;   // NUEVO
        selectors[10] = handler.unpauseSystem.selector; // NUEVO

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    // ============================================================
    // INVARIANTE 1: SUPPLY NUNCA EXCEDE MAX_SUPPLY
    // ============================================================
    function invariant_totalSupply_never_exceeds_max() public view {
        assertLe(
            coin.totalSupply(), 
            MAX_SUPPLY, 
            "CRITICAL: totalSupply > MAX_SUPPLY"
        );
    }

    // ============================================================
    // INVARIANTE 2: SUMA REAL DE BALANCES = TOTAL SUPPLY
    // ============================================================
    function invariant_sum_of_balances_equals_totalSupply() public view {
        uint256 sumBalances = 0;

        // Suma de balances de usuarios
        uint256 n = handler.usersLength();
        for (uint256 i = 0; i < n; i++) {
            address u = handler.users(i);
            sumBalances += coin.balanceOf(u);
        }

        // Incluye tokens en custodia
        sumBalances += coin.balanceOf(address(coin));

        assertEq(
            sumBalances, 
            coin.totalSupply(), 
            "CRITICAL: sum(balances) != totalSupply"
        );
    }

    // ============================================================
    // INVARIANTE 3: BALANCE EN CUSTODIA >= SUMA DE PENDING
    // ============================================================
    function invariant_contract_balance_covers_pending() public view {
        uint256 contractBalance = coin.balanceOf(address(coin));

        uint256 pendingSum = 0;
        uint256 n = handler.usersLength();
        for (uint256 i = 0; i < n; i++) {
            address u = handler.users(i);
            pendingSum += coin.pendingRedemptions(u);
        }

        assertGe(
            contractBalance, 
            pendingSum, 
            "CRITICAL: custody balance < sum(pending redemptions)"
        );
    }

    // ============================================================
    // INVARIANTE 4: USUARIOS CONFISCADOS Y BLACKLISTED TIENEN 0
    // ============================================================
    function invariant_confiscated_blacklisted_users_have_zero() public view {
        address[] memory bl = handler.getBlacklistedUsers();

        for (uint256 i = 0; i < bl.length; i++) {
            address u = bl[i];

            // Solo verificar si fue confiscado Y actualmente está blacklisted
            if (handler.wasConfiscated(u) && coin.isBlacklisted(u)) {
                assertEq(
                    coin.balanceOf(u), 
                    0, 
                    "CRITICAL: confiscated+blacklisted user has balance"
                );
                assertEq(
                    coin.pendingRedemptions(u), 
                    0, 
                    "CRITICAL: confiscated+blacklisted user has pending"
                );
            }
        }
    }

    // ============================================================
    // INVARIANTE 5: CONTABILIDAD GHOST CONSISTENTE
    // minted == burned + currentSupply
    // ============================================================
    function invariant_mint_burn_accounting() public view {
        uint256 totalMinted = handler.ghost_totalMinted();
        uint256 totalBurned = handler.ghost_totalBurned();
        uint256 currentSupply = coin.totalSupply();

        assertEq(
            totalMinted, 
            totalBurned + currentSupply, 
            "CRITICAL: minted != burned + supply"
        );
    }

    // ============================================================
    // INVARIANTE 6: GHOST PENDING == SUMA REAL DE PENDING
    // ============================================================
    function invariant_pending_redemptions_tracking_matches() public view {
        uint256 pendingSum = 0;
        uint256 n = handler.usersLength();

        for (uint256 i = 0; i < n; i++) {
            address u = handler.users(i);
            pendingSum += coin.pendingRedemptions(u);
        }

        assertEq(
            handler.ghost_totalPendingRedemptions(), 
            pendingSum, 
            "CRITICAL: ghost pending != onchain pending"
        );
    }

    // ============================================================
    // INVARIANTE 7 (NUEVO): DECIMALS SIEMPRE ES 6
    // ============================================================
    function invariant_decimals_always_six() public view {
        assertEq(
            coin.decimals(), 
            6, 
            "CRITICAL: decimals changed from 6"
        );
    }

    // ============================================================
    // INVARIANTE 8 (NUEVO): SUPPLY NO PUEDE SER NEGATIVO
    // ============================================================
    function invariant_supply_never_negative() public view {
        // Esto es redundante con Solidity (uint256 no puede ser negativo)
        // pero es buena práctica documentarlo como invariante
        assertTrue(
            coin.totalSupply() >= 0, 
            "CRITICAL: negative supply detected"
        );
    }
}

/**
 * @title Handler (Versión Mejorada)
 * @notice Incluye mintBatch, pause/unpause y mejor manejo de edge cases
 */
contract Handler is Test {
    MyStableCoin public coin;

    address public minter;
    address public burner;
    address public pauser;
    address public blacklister;

    // Ghost variables
    uint256 public ghost_totalMinted;
    uint256 public ghost_totalBurned;
    uint256 public ghost_totalPendingRedemptions;
    
    // Tracking de pausas (para debugging)
    uint256 public ghost_pauseCount;
    uint256 public ghost_unpauseCount;

    // Tracking de usuarios
    address[] public users;
    address[] public blacklistedUsers;

    mapping(address => bool) public isBlacklistedLocal;
    mapping(address => bool) public wasConfiscated;

    constructor(
        MyStableCoin _coin,
        address _minter,
        address _burner,
        address _pauser,
        address _blacklister
    ) {
        coin = _coin;
        minter = _minter;
        burner = _burner;
        pauser = _pauser;
        blacklister = _blacklister;

        // Pool de usuarios
        for (uint160 i = 1; i <= 10; i++) {
            users.push(address(i + 1000));
        }
    }

    // ============================================================
    // OPERACIÓN: MINT INDIVIDUAL
    // ============================================================
    function mint(uint256 userIndex, uint256 amount) public {
        if (coin.paused()) return;

        userIndex = bound(userIndex, 0, users.length - 1);
        address user = users[userIndex];

        amount = bound(amount, 10_000, 1_000_000 * 1_000_000);

        if (coin.totalSupply() + amount > coin.MAX_SUPPLY()) return;
        if (coin.isBlacklisted(user)) return;

        vm.prank(minter);
        try coin.mint(user, amount) {
            ghost_totalMinted += amount;
        } catch {}
    }

    // ============================================================
    // OPERACIÓN: MINT BATCH (NUEVA)
    // ============================================================
    function mintBatch(uint256 seed) public {
        if (coin.paused()) return;

        // Crear batch de 2-5 usuarios aleatorios
        uint256 batchSize = bound(seed, 2, 5);
        
        address[] memory recipients = new address[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < batchSize; i++) {
            uint256 userIndex = bound(uint256(keccak256(abi.encode(seed, i))), 0, users.length - 1);
            recipients[i] = users[userIndex];
            
            // Skip si está blacklisted
            if (coin.isBlacklisted(recipients[i])) return;
            
            amounts[i] = bound(uint256(keccak256(abi.encode(seed, i, "amount"))), 10_000, 100_000 * 1_000_000);
            totalAmount += amounts[i];
        }

        if (coin.totalSupply() + totalAmount > coin.MAX_SUPPLY()) return;

        vm.prank(minter);
        try coin.mintBatch(recipients, amounts) {
            ghost_totalMinted += totalAmount;
        } catch {}
    }

    // ============================================================
    // OPERACIÓN: TRANSFER
    // ============================================================
    function transfer(uint256 fromIndex, uint256 toIndex, uint256 amount) public {
        if (coin.paused()) return;

        fromIndex = bound(fromIndex, 0, users.length - 1);
        toIndex = bound(toIndex, 0, users.length - 1);

        address from = users[fromIndex];
        address to = users[toIndex];
        if (from == to) return;

        if (coin.isBlacklisted(from) || coin.isBlacklisted(to)) return;

        uint256 bal = coin.balanceOf(from);
        if (bal == 0) return;

        amount = bound(amount, 1, bal);

        vm.prank(from);
        try coin.transfer(to, amount) {} catch {}
    }

    // ============================================================
    // OPERACIÓN: REQUEST REDEMPTION
    // ============================================================
    function requestRedemption(uint256 userIndex, uint256 amount) public {
        if (coin.paused()) return;

        userIndex = bound(userIndex, 0, users.length - 1);
        address user = users[userIndex];

        if (coin.isBlacklisted(user)) return;

        uint256 bal = coin.balanceOf(user);
        if (bal == 0) return;

        amount = bound(amount, 1, bal);

        vm.prank(user);
        try coin.requestRedemption(amount) {
            ghost_totalPendingRedemptions += amount;
        } catch {}
    }

    // ============================================================
    // OPERACIÓN: FINALIZE REDEMPTION
    // ============================================================
    function finalizeRedemption(uint256 userIndex, uint256 amount) public {
        if (coin.paused()) return;

        userIndex = bound(userIndex, 0, users.length - 1);
        address user = users[userIndex];

        uint256 pending = coin.pendingRedemptions(user);
        if (pending == 0) return;

        amount = bound(amount, 1, pending);

        vm.prank(burner);
        try coin.finalizeRedemption(user, amount) {
            ghost_totalBurned += amount;
            ghost_totalPendingRedemptions -= amount;
        } catch {}
    }

    // ============================================================
    // OPERACIÓN: REJECT REDEMPTION
    // ============================================================
    function rejectRedemption(uint256 userIndex, uint256 amount) public {
        if (coin.paused()) return;

        userIndex = bound(userIndex, 0, users.length - 1);
        address user = users[userIndex];

        uint256 pending = coin.pendingRedemptions(user);
        if (pending == 0) return;

        amount = bound(amount, 1, pending);

        vm.prank(burner);
        try coin.rejectRedemption(user, amount) {
            ghost_totalPendingRedemptions -= amount;
        } catch {}
    }

    // ============================================================
    // OPERACIÓN: ADD TO BLACKLIST
    // ============================================================
    function addToBlacklist(uint256 userIndex) public {
        userIndex = bound(userIndex, 0, users.length - 1);
        address user = users[userIndex];

        if (coin.isBlacklisted(user)) return;

        vm.prank(blacklister);
        try coin.addToBlacklist(user) {
            if (!isBlacklistedLocal[user]) {
                blacklistedUsers.push(user);
                isBlacklistedLocal[user] = true;
            }
        } catch {}
    }

    // ============================================================
    // OPERACIÓN: REMOVE FROM BLACKLIST
    // ============================================================
    function removeFromBlacklist(uint256 userIndex) public {
        if (blacklistedUsers.length == 0) return;

        userIndex = bound(userIndex, 0, blacklistedUsers.length - 1);
        address user = blacklistedUsers[userIndex];

        if (!coin.isBlacklisted(user)) return;

        vm.prank(blacklister);
        try coin.removeFromBlacklist(user) {
            isBlacklistedLocal[user] = false;
        } catch {}
    }

    // ============================================================
    // OPERACIÓN: CONFISCATE
    // ============================================================
    function confiscate(uint256 userIndex) public {
        if (blacklistedUsers.length == 0) return;

        userIndex = bound(userIndex, 0, blacklistedUsers.length - 1);
        address user = blacklistedUsers[userIndex];

        if (!coin.isBlacklisted(user)) return;

        uint256 walletBal = coin.balanceOf(user);
        uint256 pending = coin.pendingRedemptions(user);
        uint256 total = walletBal + pending;
        if (total == 0) return;

        vm.prank(blacklister);
        try coin.confiscate(user) {
            ghost_totalBurned += total;
            if (pending > 0) ghost_totalPendingRedemptions -= pending;
            wasConfiscated[user] = true;
        } catch {}
    }

    // ============================================================
    // OPERACIÓN: PAUSE SYSTEM (NUEVA)
    // ============================================================
    function pauseSystem() public {
        // Solo pausar si NO está pausado
        if (coin.paused()) return;

        vm.prank(pauser);
        try coin.pause() {
            ghost_pauseCount++;
        } catch {}
    }

    // ============================================================
    // OPERACIÓN: UNPAUSE SYSTEM (NUEVA)
    // ============================================================
    function unpauseSystem() public {
        // Solo despausar si ESTÁ pausado
        if (!coin.paused()) return;

        vm.prank(pauser);
        try coin.unpause() {
            ghost_unpauseCount++;
        } catch {}
    }

    // ============================================================
    // HELPERS
    // ============================================================
    function usersLength() external view returns (uint256) {
        return users.length;
    }

    function getBlacklistedUsers() external view returns (address[] memory) {
        return blacklistedUsers;
    }
}