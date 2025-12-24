import { expect } from "chai";
import hre from "hardhat";

const { ethers, networkHelpers } = await hre.network.connect();
const { loadFixture } = networkHelpers;


describe("HUNBOLI - Security & Negative Tests", function () {
  
  // ============================================================
  // FIXTURE
  // ============================================================
  async function deployHunboliFixture() {
    const [admin, minter, burner, pauser, blacklistManager, user1, user2, attacker] = 
      await ethers.getSigners();

    // MAX_SUPPLY: 1 billón de BOBH (con 6 decimales)
    const MAX_SUPPLY = 1_000_000_000_000n * 1_000_000n;

    const MyStableCoin = await ethers.getContractFactory("MyStableCoin");
    const coin = await MyStableCoin.deploy(admin.address, MAX_SUPPLY);
    await coin.waitForDeployment();

    // Setup de roles
    const MINTER_ROLE = await coin.MINTER_ROLE();
    const BURNER_ROLE = await coin.BURNER_ROLE();
    const PAUSER_ROLE = await coin.PAUSER_ROLE();
    const BLACKLIST_MANAGER_ROLE = await coin.BLACKLIST_MANAGER_ROLE();
    const DEFAULT_ADMIN_ROLE = await coin.DEFAULT_ADMIN_ROLE();

    await coin.connect(admin).grantRole(MINTER_ROLE, minter.address);
    await coin.connect(admin).grantRole(BURNER_ROLE, burner.address);
    await coin.connect(admin).grantRole(PAUSER_ROLE, pauser.address);
    await coin.connect(admin).grantRole(BLACKLIST_MANAGER_ROLE, blacklistManager.address);

    return { 
      coin, 
      admin, 
      minter, 
      burner, 
      pauser, 
      blacklistManager, 
      user1, 
      user2, 
      attacker,
      MINTER_ROLE,
      BURNER_ROLE,
      PAUSER_ROLE,
      BLACKLIST_MANAGER_ROLE,
      DEFAULT_ADMIN_ROLE,
      MAX_SUPPLY
    };
  }

  // ============================================================
  // 1. ESPECIFICACIONES BÁSICAS
  // ============================================================
  describe("1. Token Specifications", function () {
    it("✅ Debe tener 6 decimales (según spec HUNBOLI)", async () => {
      const { coin } = await loadFixture(deployHunboliFixture);
      expect(await coin.decimals()).to.equal(6);
    });

    it("✅ Debe tener nombre 'HUNBOLI' y símbolo 'BOBH'", async () => {
      const { coin } = await loadFixture(deployHunboliFixture);
      expect(await coin.name()).to.equal("HUNBOLI");
      expect(await coin.symbol()).to.equal("BOBH");
    });

    it("✅ MAX_SUPPLY debe estar configurado correctamente", async () => {
      const { coin, MAX_SUPPLY } = await loadFixture(deployHunboliFixture);
      expect(await coin.MAX_SUPPLY()).to.equal(MAX_SUPPLY);
    });
  });

  // ============================================================
  // 2. CONTROL DE ACCESO - MINT
  // ============================================================
  describe("2. Mint Access Control", function () {
    it("🔴 mint() debe revertir si lo llama un usuario sin MINTER_ROLE", async () => {
      const { coin, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(user1).mint(user1.address, 1000000n)
      ).to.be.revertedWithCustomError(coin, "AccessControlUnauthorizedAccount");
    });

    it("🔴 mint() debe revertir si lo llama el atacante", async () => {
      const { coin, attacker } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(attacker).mint(attacker.address, 1000000n)
      ).to.be.revertedWithCustomError(coin, "AccessControlUnauthorizedAccount");
    });

    it("✅ mint() debe funcionar correctamente con MINTER_ROLE", async () => {
      const { coin, minter, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(minter).mint(user1.address, 1000000n)
      ).to.emit(coin, "Minted").withArgs(minter.address, user1.address, 1000000n);
      
      expect(await coin.balanceOf(user1.address)).to.equal(1000000n);
    });

    it("🔴 No se puede mintear a address(0)", async () => {
      const { coin, minter } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(minter).mint(ethers.ZeroAddress, 1000000n)
      ).to.be.revertedWithCustomError(coin, "ERC20InvalidReceiver");
    });

    it("🔴 No se puede exceder MAX_SUPPLY", async () => {
      const { coin, minter, user1, MAX_SUPPLY } = await loadFixture(deployHunboliFixture);
      
      // Mintear hasta el límite
      await coin.connect(minter).mint(user1.address, MAX_SUPPLY);
      
      // Intentar mintear más
      await expect(
        coin.connect(minter).mint(user1.address, 1n)
      ).to.be.revertedWith("Exceeds maximum supply");
    });
  });

  // ============================================================
  // 3. CONTROL DE ACCESO - BURN
  // ============================================================
  describe("3. Burn Access Control", function () {
    it("🔴 finalizeRedemption() debe revertir si no tiene BURNER_ROLE", async () => {
      const { coin, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(user1).finalizeRedemption(user1.address, 100n)
      ).to.be.revertedWithCustomError(coin, "AccessControlUnauthorizedAccount");
    });

    it("🔴 rejectRedemption() debe revertir si no tiene BURNER_ROLE", async () => {
      const { coin, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(user1).rejectRedemption(user1.address, 100n)
      ).to.be.revertedWithCustomError(coin, "AccessControlUnauthorizedAccount");
    });

    it("✅ finalizeRedemption() debe funcionar con BURNER_ROLE", async () => {
      const { coin, minter, burner, user1 } = await loadFixture(deployHunboliFixture);
      
      // Setup: mintear tokens y hacer request
      await coin.connect(minter).mint(user1.address, 1000000n);
      await coin.connect(user1).requestRedemption(1000000n);
      
      // Burn
      await expect(
        coin.connect(burner).finalizeRedemption(user1.address, 1000000n)
      ).to.emit(coin, "RedemptionFinalized")
       .and.to.emit(coin, "Burned").withArgs(burner.address, user1.address, 1000000n);
      
      expect(await coin.balanceOf(coin.target)).to.equal(0);
      expect(await coin.totalSupply()).to.equal(0);
    });
  });

  // ============================================================
  // 4. BLACKLIST - BLOQUEO DE TRANSFERENCIAS
  // ============================================================
  describe("4. Blacklist Security", function () {
    it("🔴 Usuario en blacklist NO puede recibir tokens", async () => {
      const { coin, minter, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      // Agregar a blacklist
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      
      // Intentar mintear -> debe fallar
      await expect(
        coin.connect(minter).mint(user1.address, 1000000n)
      ).to.be.revertedWith("Recipient is blacklisted");
    });

    it("🔴 Usuario en blacklist NO puede enviar tokens", async () => {
      const { coin, minter, blacklistManager, user1, user2 } = await loadFixture(deployHunboliFixture);
      
      // Mintear tokens primero
      await coin.connect(minter).mint(user1.address, 1000000n);
      
      // Luego agregar a blacklist
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      
      // Intentar transferir -> debe fallar
      await expect(
        coin.connect(user1).transfer(user2.address, 500000n)
      ).to.be.revertedWith("Sender is blacklisted");
    });

    it("🔴 Usuario en blacklist NO puede solicitar redención", async () => {
      const { coin, minter, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      // Mintear tokens
      await coin.connect(minter).mint(user1.address, 1000000n);
      
      // Agregar a blacklist
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      
      // Intentar redimir -> debe fallar en _transfer interno
      await expect(
        coin.connect(user1).requestRedemption(500000n)
      ).to.be.revertedWith("Sender is blacklisted");
    });

    it("🔴 addToBlacklist() debe revertir si no tiene BLACKLIST_MANAGER_ROLE", async () => {
      const { coin, attacker, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(attacker).addToBlacklist(user1.address)
      ).to.be.revertedWithCustomError(coin, "AccessControlUnauthorizedAccount");
    });

    it("🔴 No se puede agregar dos veces a la blacklist", async () => {
      const { coin, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      
      await expect(
        coin.connect(blacklistManager).addToBlacklist(user1.address)
      ).to.be.revertedWith("Account already blacklisted");
    });

    it("✅ Usuario removido de blacklist puede operar nuevamente", async () => {
      const { coin, minter, blacklistManager, user1, user2 } = await loadFixture(deployHunboliFixture);
      
      // Mintear, agregar a blacklist, remover
      await coin.connect(minter).mint(user1.address, 1000000n);
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      await coin.connect(blacklistManager).removeFromBlacklist(user1.address);
      
      // Ahora sí puede transferir
      await coin.connect(user1).transfer(user2.address, 500000n);
      expect(await coin.balanceOf(user2.address)).to.equal(500000n);
    });

    it("🔴 removeFromBlacklist() debe revertir si la cuenta no está en blacklist", async () => {
      const { coin, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(blacklistManager).removeFromBlacklist(user1.address)
      ).to.be.revertedWith("Account not blacklisted");
    });

    it("✅ addToBlacklist debe emitir evento con el admin que lo ejecutó", async () => {
      const { coin, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(blacklistManager).addToBlacklist(user1.address)
      ).to.emit(coin, "AddedToBlacklist").withArgs(user1.address, blacklistManager.address);
    });
  });

  // ============================================================
  // 5. CONFISCACIÓN (Nueva funcionalidad)
  // ============================================================
  describe("5. Confiscation", function () {
    it("✅ Puede confiscar fondos de wallet de usuario blacklisted", async () => {
      const { coin, minter, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      // Setup
      await coin.connect(minter).mint(user1.address, 1000000n);
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      
      // Confiscar
      await expect(
        coin.connect(blacklistManager).confiscate(user1.address)
      ).to.emit(coin, "Confiscated").withArgs(user1.address, 1000000n)
       .and.to.emit(coin, "Burned");
      
      expect(await coin.balanceOf(user1.address)).to.equal(0);
    });

    it("✅ Puede confiscar fondos pendientes de redención", async () => {
      const { coin, minter, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      // Setup: usuario solicita redención
      await coin.connect(minter).mint(user1.address, 1000000n);
      await coin.connect(user1).requestRedemption(1000000n);
      
      // Blacklistear y confiscar
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      await coin.connect(blacklistManager).confiscate(user1.address);
      
      expect(await coin.pendingRedemptions(user1.address)).to.equal(0);
      expect(await coin.balanceOf(coin.target)).to.equal(0);
    });

    it("✅ Puede confiscar fondos de wallet + pendientes simultáneamente", async () => {
      const { coin, minter, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      // Setup: usuario tiene en wallet y en pending
      await coin.connect(minter).mint(user1.address, 2000000n);
      await coin.connect(user1).requestRedemption(1000000n);
      
      // Blacklistear y confiscar
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      
      await expect(
        coin.connect(blacklistManager).confiscate(user1.address)
      ).to.emit(coin, "Confiscated").withArgs(user1.address, 2000000n);
      
      expect(await coin.balanceOf(user1.address)).to.equal(0);
      expect(await coin.pendingRedemptions(user1.address)).to.equal(0);
    });

    it("🔴 No puede confiscar si usuario no está en blacklist", async () => {
      const { coin, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(blacklistManager).confiscate(user1.address)
      ).to.be.revertedWith("User is not blacklisted");
    });

    it("🔴 confiscate() debe revertir si no tiene BLACKLIST_MANAGER_ROLE", async () => {
      const { coin, attacker, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(attacker).confiscate(user1.address)
      ).to.be.revertedWithCustomError(coin, "AccessControlUnauthorizedAccount");
    });
  });

  // ============================================================
  // 6. PAUSA DE EMERGENCIA
  // ============================================================
  describe("6. Emergency Pause", function () {
    it("🔴 Cuando está pausado, NO se puede transferir", async () => {
      const { coin, minter, pauser, user1, user2 } = await loadFixture(deployHunboliFixture);
      
      // Mintear tokens
      await coin.connect(minter).mint(user1.address, 1000000n);
      
      // Pausar
      await coin.connect(pauser).pause();
      
      // Intentar transferir
      await expect(
        coin.connect(user1).transfer(user2.address, 500000n)
      ).to.be.revertedWithCustomError(coin, "EnforcedPause");
    });

    it("🔴 Cuando está pausado, NO se puede mintear", async () => {
      const { coin, minter, pauser, user1 } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(pauser).pause();
      
      await expect(
        coin.connect(minter).mint(user1.address, 1000000n)
      ).to.be.revertedWithCustomError(coin, "EnforcedPause");
    });

    it("🔴 Cuando está pausado, NO se puede solicitar redención", async () => {
      const { coin, minter, pauser, user1 } = await loadFixture(deployHunboliFixture);
      
      // Mintear primero
      await coin.connect(minter).mint(user1.address, 1000000n);
      
      // Pausar
      await coin.connect(pauser).pause();
      
      // Intentar redimir
      await expect(
        coin.connect(user1).requestRedemption(500000n)
      ).to.be.revertedWithCustomError(coin, "EnforcedPause");
    });

    it("🔴 pause() debe revertir si no tiene PAUSER_ROLE", async () => {
      const { coin, attacker } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(attacker).pause()
      ).to.be.revertedWithCustomError(coin, "AccessControlUnauthorizedAccount");
    });

    it("✅ Después de unpause(), las operaciones funcionan normalmente", async () => {
      const { coin, minter, pauser, user1, user2 } = await loadFixture(deployHunboliFixture);
      
      // Mintear, pausar, despausar
      await coin.connect(minter).mint(user1.address, 1000000n);
      await coin.connect(pauser).pause();
      await coin.connect(pauser).unpause();
      
      // Ahora sí puede transferir
      await coin.connect(user1).transfer(user2.address, 500000n);
      expect(await coin.balanceOf(user2.address)).to.equal(500000n);
    });

    it("✅ pause() debe emitir SystemPaused", async () => {
      const { coin, pauser } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(pauser).pause()
      ).to.emit(coin, "SystemPaused").withArgs(pauser.address);
    });

    it("✅ unpause() debe emitir SystemUnpaused", async () => {
      const { coin, pauser } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(pauser).pause();
      
      await expect(
        coin.connect(pauser).unpause()
      ).to.emit(coin, "SystemUnpaused").withArgs(pauser.address);
    });
  });

  // ============================================================
  // 7. PROCESO DE REDENCIÓN
  // ============================================================
  describe("7. Redemption Process", function () {
    it("🔴 requestRedemption() debe revertir si el usuario no tiene suficiente balance", async () => {
      const { coin, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(user1).requestRedemption(1000000n)
      ).to.be.revertedWith("Saldo insuficiente");
    });

    it("🔴 finalizeRedemption() debe revertir si no hay tokens en custodia", async () => {
      const { coin, burner, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(burner).finalizeRedemption(user1.address, 1000000n)
      ).to.be.revertedWith("Monto incorrecto");
    });

    it("🔴 rejectRedemption() debe revertir si no hay tokens en custodia", async () => {
      const { coin, burner, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(burner).rejectRedemption(user1.address, 1000000n)
      ).to.be.revertedWith("Monto incorrecto");
    });

    it("✅ Flujo completo de redención exitosa", async () => {
      const { coin, minter, burner, user1 } = await loadFixture(deployHunboliFixture);
      
      // 1. Mintear tokens
      await coin.connect(minter).mint(user1.address, 1000000n);
      
      // 2. Usuario solicita redención
      await expect(
        coin.connect(user1).requestRedemption(1000000n)
      ).to.emit(coin, "RedemptionRequested");
      
      expect(await coin.balanceOf(coin.target)).to.equal(1000000n);
      expect(await coin.balanceOf(user1.address)).to.equal(0);
      expect(await coin.pendingRedemptions(user1.address)).to.equal(1000000n);
      
      // 3. Operador finaliza redención
      await expect(
        coin.connect(burner).finalizeRedemption(user1.address, 1000000n)
      ).to.emit(coin, "RedemptionFinalized");
      
      expect(await coin.totalSupply()).to.equal(0);
      expect(await coin.pendingRedemptions(user1.address)).to.equal(0);
    });

    it("✅ Flujo completo de redención rechazada", async () => {
      const { coin, minter, burner, user1 } = await loadFixture(deployHunboliFixture);
      
      // 1. Mintear tokens
      await coin.connect(minter).mint(user1.address, 1000000n);
      
      // 2. Usuario solicita redención
      await coin.connect(user1).requestRedemption(1000000n);
      
      // 3. Operador rechaza redención
      await expect(
        coin.connect(burner).rejectRedemption(user1.address, 1000000n)
      ).to.emit(coin, "RedemptionRejected");
      
      // Tokens devueltos al usuario
      expect(await coin.balanceOf(user1.address)).to.equal(1000000n);
      expect(await coin.balanceOf(coin.target)).to.equal(0);
      expect(await coin.pendingRedemptions(user1.address)).to.equal(0);
    });

    it("✅ SOLUCIONADO: rejectRedemption() ahora funciona incluso si usuario fue bloqueado", async () => {
      const { coin, minter, burner, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      // 1. Mintear y solicitar redención
      await coin.connect(minter).mint(user1.address, 1000000n);
      await coin.connect(user1).requestRedemption(1000000n);
      
      // 2. DURANTE LA ESPERA: usuario es agregado a blacklist
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      
      // 3. Como burner tiene BURNER_ROLE, puede devolver tokens incluso a blacklisted
      // La lógica de _update permite acciones administrativas
      await expect(
        coin.connect(burner).rejectRedemption(user1.address, 1000000n)
      ).to.emit(coin, "RedemptionRejected");
      
      // ✅ Tokens devueltos exitosamente
      expect(await coin.balanceOf(user1.address)).to.equal(1000000n);
    });

    it("🔴 finalizeRedemption() no debe poder quemar más tokens de los solicitados", async () => {
      const { coin, minter, burner, user1 } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(minter).mint(user1.address, 1000000n);
      await coin.connect(user1).requestRedemption(500000n);
      
      // Intentar quemar más de lo solicitado
      await expect(
        coin.connect(burner).finalizeRedemption(user1.address, 1000000n)
      ).to.be.revertedWith("Monto incorrecto");
    });

    it("✅ Usuario puede hacer múltiples solicitudes de redención", async () => {
      const { coin, minter, user1 } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(minter).mint(user1.address, 3000000n);
      
      await coin.connect(user1).requestRedemption(1000000n);
      await coin.connect(user1).requestRedemption(1000000n);
      
      expect(await coin.pendingRedemptions(user1.address)).to.equal(2000000n);
      expect(await coin.balanceOf(user1.address)).to.equal(1000000n);
    });
  });

  // ============================================================
  // 8. OVERFLOW & EDGE CASES
  // ============================================================
  describe("8. Overflow & Edge Cases", function () {
    it("✅ Puede mintear hasta MAX_SUPPLY", async () => {
      const { coin, minter, user1, MAX_SUPPLY } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(minter).mint(user1.address, MAX_SUPPLY);
      expect(await coin.balanceOf(user1.address)).to.equal(MAX_SUPPLY);
    });

    it("🔴 No puede mintear si causaría overflow de MAX_SUPPLY", async () => {
      const { coin, minter, user1, user2, MAX_SUPPLY } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(minter).mint(user1.address, MAX_SUPPLY);
      
      // Intentar mintear más -> overflow
      await expect(
        coin.connect(minter).mint(user2.address, 1n)
      ).to.be.revertedWith("Exceeds maximum supply");
    });

    it("✅ Puede operar con cantidades de 6 decimales correctamente", async () => {
      const { coin, minter, user1, user2 } = await loadFixture(deployHunboliFixture);
      
      // 1.50 BOB = 1_500_000 (con 6 decimales)
      const amount = 1_500_000n;
      await coin.connect(minter).mint(user1.address, amount);
      
      await coin.connect(user1).transfer(user2.address, amount / 2n);
      
      expect(await coin.balanceOf(user1.address)).to.equal(750_000n);
      expect(await coin.balanceOf(user2.address)).to.equal(750_000n);
    });
  });

  // ============================================================
  // 9. GESTIÓN DE ROLES
  // ============================================================
  describe("9. Role Management", function () {
    it("🔴 Usuario sin DEFAULT_ADMIN_ROLE no puede otorgar roles", async () => {
      const { coin, user1, user2, MINTER_ROLE } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(user1).grantRole(MINTER_ROLE, user2.address)
      ).to.be.revertedWithCustomError(coin, "AccessControlUnauthorizedAccount");
    });

    it("✅ Admin puede otorgar y revocar roles", async () => {
      const { coin, admin, user1, MINTER_ROLE } = await loadFixture(deployHunboliFixture);
      
      // Otorgar
      await coin.connect(admin).grantRole(MINTER_ROLE, user1.address);
      expect(await coin.hasRole(MINTER_ROLE, user1.address)).to.be.true;
      
      // Revocar
      await coin.connect(admin).revokeRole(MINTER_ROLE, user1.address);
      expect(await coin.hasRole(MINTER_ROLE, user1.address)).to.be.false;
    });

    it("🔴 Si se revoca MINTER_ROLE, ya no puede mintear", async () => {
      const { coin, admin, minter, user1, MINTER_ROLE } = await loadFixture(deployHunboliFixture);
      
      // Revocar rol
      await coin.connect(admin).revokeRole(MINTER_ROLE, minter.address);
      
      // Intentar mintear
      await expect(
        coin.connect(minter).mint(user1.address, 1000000n)
      ).to.be.revertedWithCustomError(coin, "AccessControlUnauthorizedAccount");
    });
  });

  // ============================================================
  // 10. EVENTOS DE AUDITORÍA
  // ============================================================
  describe("10. Audit Events", function () {
    it("✅ Debe emitir evento Minted con los parámetros correctos", async () => {
      const { coin, minter, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(minter).mint(user1.address, 1000000n)
      ).to.emit(coin, "Minted")
       .withArgs(minter.address, user1.address, 1000000n);
    });

    it("✅ Debe emitir evento Burned en finalizeRedemption", async () => {
      const { coin, minter, burner, user1 } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(minter).mint(user1.address, 1000000n);
      await coin.connect(user1).requestRedemption(1000000n);
      
      await expect(
        coin.connect(burner).finalizeRedemption(user1.address, 1000000n)
      ).to.emit(coin, "Burned")
       .withArgs(burner.address, user1.address, 1000000n);
    });

    it("✅ Debe emitir evento AddedToBlacklist con admin correcto", async () => {
      const { coin, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      await expect(
        coin.connect(blacklistManager).addToBlacklist(user1.address)
      ).to.emit(coin, "AddedToBlacklist")
       .withArgs(user1.address, blacklistManager.address);
    });

    it("✅ Debe emitir evento RemovedFromBlacklist", async () => {
      const { coin, blacklistManager, user1 } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(blacklistManager).addToBlacklist(user1.address);
      
      await expect(
        coin.connect(blacklistManager).removeFromBlacklist(user1.address)
      ).to.emit(coin, "RemovedFromBlacklist")
       .withArgs(user1.address, blacklistManager.address);
    });

    it("✅ Debe emitir evento RedemptionRequested", async () => {
      const { coin, minter, user1 } = await loadFixture(deployHunboliFixture);
      
      await coin.connect(minter).mint(user1.address, 1000000n);
      
      await expect(
        coin.connect(user1).requestRedemption(1000000n)
      ).to.emit(coin, "RedemptionRequested")
       .withArgs(user1.address, 1000000n);
    });
  });
});