pragma solidity ^0.4.25;

contract TronsCraft {
    address creator = msg.sender;
    
    struct Pixel {
        address owner;
        uint price;
        uint color;
    }

    struct Coord {
        uint x;
        uint y;
        uint z;
    }

    uint initialPrice = 10000000; // 10 TRX
    uint priceStep = 25; // 25%
    uint maxX = 100;
    uint maxY = 100;
    uint maxZ = 100;

    mapping (uint => mapping(uint => mapping(uint => Pixel))) public map;
    Coord[] public coords;
    uint public coordCount;

    event PixelUpdate(uint x, uint y, uint z, address owner, uint price, uint color);

    function placePixel(uint x, uint y, uint z, uint color) public payable {
        require(x < maxX);
        require(y < maxY);
        require(z < maxZ);
        require(color < 0x1000000);
        Pixel storage pixel = map[x][y][z];

        uint newPrice;
        if (pixel.price > 0) {
            newPrice = pixel.price + pixel.price * priceStep / 100;
        } else {
            newPrice = initialPrice;
        }
        
        require(msg.value == newPrice);

        if (pixel.owner == 0x0) {
            creator.transfer(msg.value);
            coords.push(Coord(x, y, z));
            coordCount++;
        } else {
            uint diff = msg.value - pixel.price >> 1;
            pixel.owner.transfer(pixel.price + diff);
            creator.transfer(diff);
        }

        map[x][y][z] = Pixel(msg.sender, newPrice, color);

        emit PixelUpdate(x, y, z, msg.sender, newPrice, color);
    }
}