import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();

describe("Mint & Burn via Vault (happy path)", function () {

    async function deployFixture() {
        const [owner, user1] = await ethers.getSigners();

        // Deploy mock USDC
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        const usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
        await usdc.waitForDeployment();

        // Deploy stablecoin
        const StableCoin = await ethers.getContractFactory("MyStableCoin");
        const stable = await StableCoin.deploy();
        await stable.waitForDeployment();

        // Deploy vault (setea vault automáticamente)
        const Vault = await ethers.getContractFactory("StableCoinVault");
        const vault = await Vault.deploy(
            await stable.getAddress(),
            await usdc.getAddress()
        );
        await vault.waitForDeployment();

        return { owner, user1, usdc, stable, vault };
    }

    it("should mint stablecoins when collateral is deposited", async function () {
        const { user1, usdc, stable, vault } = await deployFixture();

        const collateral = 150_000_000; // 150 USDC (6 dec)
        const expectedMint = 100_000_000; // 100 BOBH

        // Dar USDC al usuario
        await usdc.mint(user1.address, collateral);

        // Aprobar Vault
        await usdc.connect(user1).approve(
            await vault.getAddress(),
            collateral
        );

        // Mint vía Vault
        await vault.connect(user1).mintStable(collateral);

        // Assertions
        expect(await stable.balanceOf(user1.address))
            .to.equal(expectedMint);

        expect(await stable.totalSupply())
            .to.equal(expectedMint);

        expect(await vault.depositedCollateral(user1.address))
            .to.equal(collateral);
    });

    it("should burn stablecoins and return collateral", async function () {
        const { user1, usdc, stable, vault } = await deployFixture();

        const collateral = 150_000_000; // 150 USDC
        const mintAmount = 100_000_000; // 100 BOBH
        const burnAmount = 50_000_000;  // 50 BOBH
        const expectedReturn = 75_000_000; // 75 USDC

        // Setup: mint primero
        await usdc.mint(user1.address, collateral);
        await usdc.connect(user1).approve(
            await vault.getAddress(),
            collateral
        );
        await vault.connect(user1).mintStable(collateral);

        // Burn vía Vault
        await vault.connect(user1).redeemStable(burnAmount);

        // Assertions
        expect(await stable.balanceOf(user1.address))
            .to.equal(mintAmount - burnAmount);

        expect(await vault.depositedCollateral(user1.address))
            .to.equal(collateral - expectedReturn);
    });
});
