import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();

describe("SecurityPlayground - Happy Paths & Modules", function () {
    async function deployFixture() {
        const [admin, minter, user] = await ethers.getSigners();
        const Playground = await ethers.getContractFactory("SecurityPlayground");
        const playground = await Playground.deploy(admin.address);
        await playground.waitForDeployment();

        // Roles constantes
        const MINTER_ROLE = await playground.MINTER_ROLE();
        const PAUSER_ROLE = await playground.PAUSER_ROLE();

        return { playground, admin, minter, user, MINTER_ROLE, PAUSER_ROLE };
    }

    describe("Roles Module", function () {
        it("should allow admin to grant MINTER_ROLE", async function () {
            const { playground, admin, minter, MINTER_ROLE } = await deployFixture();

            // Happy path: Admin da rol
            await playground.connect(admin).grantRole(MINTER_ROLE, minter.address);

            expect(await playground.hasRole(MINTER_ROLE, minter.address)).to.be.true;
        });

        it("should allow a new minter to mint", async function () {
            const { playground, admin, minter, user, MINTER_ROLE } = await deployFixture();

            // Setup
            await playground.connect(admin).grantRole(MINTER_ROLE, minter.address);

            // Happy path: Mint exitoso
            await expect(playground.connect(minter).mint(user.address, 100))
                .to.emit(playground, "Mint")
                .withArgs(user.address, 100);
        });
    });

    describe("Pause Module", function () {
        it("should allow PAUSER to pause and unpause", async function () {
            const { playground, admin } = await deployFixture();

            // 1. Pause
            await playground.connect(admin).pause();
            expect(await playground.paused()).to.be.true;

            // 2. Unpause
            await playground.connect(admin).unpause();
            expect(await playground.paused()).to.be.false;
        });

        it("should prevent minting while paused (integration check)", async function () {
            const { playground, admin, user } = await deployFixture();

            await playground.connect(admin).pause();

            // Aunque sea admin/minter, no debe poder mintear si está pausado
            // Nota: Esto es un borde entre unitario y funcional
            await expect(playground.connect(admin).mint(user.address, 100))
                .to.be.revertedWithCustomError(playground, "EnforcedPause"); // Depende de tu versión de OZ
        });
    });

    describe("Blacklist Module", function () {
        it("should allow admin to blacklist and un-blacklist a user", async function () {
            const { playground, admin, user } = await deployFixture();

            // 1. Blacklist
            await expect(playground.connect(admin).setBlacklisted(user.address, true))
                .to.emit(playground, "BlacklistUpdated")
                .withArgs(user.address, true);

            expect(await playground.blacklisted(user.address)).to.be.true;

            // 2. Un-blacklist
            await playground.connect(admin).setBlacklisted(user.address, false);
            expect(await playground.blacklisted(user.address)).to.be.false;
        });
    });
});