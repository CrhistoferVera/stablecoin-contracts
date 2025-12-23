import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();
describe("SimpleStorage", function () {
    async function deploySimpleStorage() {
        const SimpleStorage = await ethers.getContractFactory("SimpleStorage");
        const simpleStorage = await SimpleStorage.deploy();
        await simpleStorage.waitForDeployment();
        return simpleStorage;
    }
    it("Should store and retrieve a value", async function () {
        const simpleStorage = await deploySimpleStorage();
        await simpleStorage.store(123);
        const storedValue = await simpleStorage.retrieve();
        expect(storedValue).to.equal(123);
    });
    it("Should add and retrieve a person", async function () {
        const simpleStorage = await deploySimpleStorage();
        await simpleStorage.addPerson("Bob", 25);
        const person = await simpleStorage.people(0);
        expect(person.name).to.equal("Bob");
        expect(person.favoriteNumber).to.equal(25);
    });
    it("Should update stored value correctly", async function () {
        const simpleStorage = await deploySimpleStorage();
        await simpleStorage.store(10);
        let storedValue = await simpleStorage.retrieve();
        expect(storedValue).to.equal(10);
        await simpleStorage.store(20);
        storedValue = await simpleStorage.retrieve();
        expect(storedValue).to.equal(20);
    });
});

