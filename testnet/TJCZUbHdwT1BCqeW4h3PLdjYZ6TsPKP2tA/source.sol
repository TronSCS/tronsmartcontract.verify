contract StringStorage {

    address public owner;

    mapping(address => string) public words;

    function StringStorage()
        public
    {
        owner = msg.sender;
    }

    function storeString(string memory word)
        public
    {
        words[msg.sender] = word;
    }
}