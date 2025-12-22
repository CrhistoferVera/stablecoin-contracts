// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract SimpleStorage {
    uint256 public favoriteNumber;
    struct Person {
        uint256 favoriteNumber;
        string name;
    }

    Person[] public people;
    mapping(string => uint256) public nameToFavoriteNumber;
    function store(uint256 number) public {
        favoriteNumber = number;
    }
    function retrieve() public view returns (uint256) {
        return favoriteNumber;
    }
    function addPerson(string memory name, uint256 number) public {
        people.push(Person(number, name));
        nameToFavoriteNumber[name] = number;
    }
    function getPeople() public view returns (Person[] memory) {
        return people;
    }
}
