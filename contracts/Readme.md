npx hardhat console --network localhost
2️⃣ Conectar ethers al network
javascript
Copiar código
const { ethers } = await network.connect();
3️⃣ Desplegar contratos
javascript
Copiar código
// Deploy MyStableCoin
const coin = await ethers.deployContract("MyStableCoin");
await coin.waitForDeployment();
console.log("StableCoin deployed at:", coin.target);

// Deploy ERC20Mock (USDC Test)
const collateral = await ethers.deployContract("ERC20Mock", ["USDC Test", "USDC", 6]);
await collateral.waitForDeployment();
console.log("Collateral deployed at:", collateral.target);

// Deploy StableCoinVault
const vault = await ethers.deployContract("StableCoinVault", [coin.target, collateral.target]);
await vault.waitForDeployment();
console.log("Vault deployed at:", vault.target);
4️⃣ Asignar Vault al token (solo se puede hacer una vez)
javascript
Copiar código
await coin.setVault(vault.target);
⚠️ Nota: En tu sesión dio error algunas veces por sintaxis de await y errores internos.

5️⃣ Obtener signers
javascript
Copiar código
const [owner, user1, user2] = await ethers.getSigners();
console.log("Owner:", owner.address);
console.log("User1:", user1.address);
console.log("User2:", user2.address);
6️⃣ Preparar colateral (USDC) y aprobar Vault
javascript
Copiar código
const depositAmount = 150n * 1_000_000n; // 150 USDC con 6 decimales

// Mint de USDC al owner
await collateral.mint(owner.address, depositAmount);

// Aprobar que el vault use el colateral
await collateral.approve(vault.target, depositAmount);
7️⃣ Mint de BOBH usando el Vault
javascript
Copiar código
await vault.mintStable(depositAmount);
console.log("Stablecoin mint realizada con éxito");
8️⃣ Transferencia de BOBH a otro usuario
javascript
Copiar código
const transferAmount = 50n * 1_000_000n; // 50 BOBH
await coin.transfer(user1.address, transferAmount);
console.log("Transferencia realizada a user1");
9️⃣ Consultar balances finales
javascript
Copiar código
console.log("Owner balance:", await coin.balanceOf(owner.address));
console.log("User1 balance:", await coin.balanceOf(user1.address));