import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();

describe("Token - basic behavior", function () {
    async function deployFixture() {
        const [owner, user1, user2] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("MyStableCoin");
        const token = await Token.deploy();
        await token.waitForDeployment();
        return { token, owner, user1, user2 };
    }
    it("should have correct name and symbol", async function () {
        const Token = await ethers.getContractFactory("MyStableCoin");
        const token = await Token.deploy();
        await token.waitForDeployment();
        expect(await token.name()).to.equal("HUNBOLI");
        expect(await token.symbol()).to.equal("BOBH");
    });

    it("should have correct decimals", async function () {
        const { token } = await deployFixture();
        expect(await token.decimals()).to.equal(6);
    });

    it("should start with zero total supply", async function () {
        const { token } = await deployFixture();
        expect(await token.totalSupply()).to.equal(0);
    });
    it("should have vault = address(0) initially", async function () {
        const { token } = await deployFixture();
        expect(await token.vault()).to.equal(ethers.ZeroAddress);
    });
    it("should set vault successfully (Happy Path)", async function () {

        const { token, owner, user1 } = await deployFixture();
        // El test negativo ya prueba que no se puede setear 2 veces,
        // pero tú necesitas validar que la primera vez SÍ funciona.
        await token.connect(owner).setVault(user1.address);
        expect(await token.vault()).to.equal(user1.address);
    });
});