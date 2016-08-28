from ethjsonrpc import EthJsonRpc
from ethereum.tester import languages, state
from ethereum.abi import ContractTranslator
from ethereum.transactions import Transaction
from ethereum.utils import privtoaddr
from preprocessor import PreProcessor
import click
import time
import json
import rlp


addresses = {}
abis = {}
pp = PreProcessor()
s = state()


def wait_for_transaction_receipt(json_rpc, transaction_hash):
    while json_rpc.eth_getTransactionReceipt(transaction_hash)['result'] is None:
        print "Waiting for transaction receipt {}".format(transaction_hash)
        time.sleep(5)


def deploy_code(json_rpc, coinbase, file_path, constructor_params, contract_addresses, add_dev_code, contract_dir, gas, gas_price, private_key):
    if file_path not in addresses.keys():
        if contract_addresses:
            a_copy = addresses.copy()
            a_copy.update(contract_addresses)
            contract_addresses = a_copy
        else:
            contract_addresses = addresses
        language = "solidity" if file_path.endswith(".sol") else "serpent"
        code = pp.process(file_path, add_dev_code=add_dev_code, contract_dir=contract_dir, addresses=contract_addresses)
        # compile code
        combined = languages[language].combined(code)
        compiled_code = combined[-1][1]["bin_hex"]
        abi = combined[-1][1]["abi"]
        # replace library placeholders
        for library_name, library_address in contract_addresses.iteritems():
            compiled_code = compiled_code.replace("__{}{}".format(library_name, "_" * (38-len(library_name))), library_address[2:])
        if constructor_params:
            translator = ContractTranslator(abi)
            compiled_code += translator.encode_constructor_arguments(constructor_params).encode("hex")
        print 'Try to create contract with length {} based on code in file: {}'.format(len(compiled_code), file_path)
        if private_key:
            address = privtoaddr(private_key.decode('hex'))
            nonce = int(json_rpc.eth_getTransactionCount('0x' + address.encode('hex'))["result"][2:], 16)
            tx = Transaction(nonce, gas_price, gas, '', 0, compiled_code.decode('hex'))
            tx.sign(private_key.decode('hex'))
            raw_tx = rlp.encode(tx).encode('hex')
            transaction_hash = json_rpc.eth_sendRawTransaction("0x" + raw_tx)["result"]
        else:
            transaction_hash = json_rpc.eth_sendTransaction(coinbase, data=compiled_code, gas=gas, gas_price=gas_price)["result"]
        wait_for_transaction_receipt(json_rpc, transaction_hash)
        contract_address = json_rpc.eth_getTransactionReceipt(transaction_hash)["result"]["contractAddress"]
        locally_deployed_code_address = s.evm(compiled_code.decode("hex")).encode("hex")
        locally_deployed_code = s.block.get_code(locally_deployed_code_address).encode("hex")
        deployed_code = json_rpc.eth_getCode(contract_address)["result"]
        if deployed_code != "0x" + locally_deployed_code:
            print 'Deploy of {} failed. Retry!'.format(file_path)
            deploy_code(json_rpc, coinbase, file_path, constructor_params, contract_addresses, add_dev_code, contract_dir, gas, gas_price, private_key)
        contract_name = file_path.split("/")[-1].split(".")[0]
        addresses[contract_name] = contract_address
        abis[contract_name] = abi
        print 'Contract {} was created at address {}.'.format(file_path, contract_address)


def do_transaction(json_rpc, coinbase, contract, name, params, gas, gas_price, private_key):
    contract_address = addresses[contract] if contract in addresses else contract
    contract_abi = abis[contract]
    translator = ContractTranslator(contract_abi)
    data = translator.encode(name, [addresses[param] if param in addresses else param for param in params]).encode("hex")
    print 'Try to send {} transaction to contract {}.'.format(name, contract)
    if private_key:
        address = privtoaddr(private_key.decode('hex'))
        nonce = int(json_rpc.eth_getTransactionCount('0x' + address.encode('hex'))["result"][2:], 16)
        tx = Transaction(nonce, gas_price, gas, contract_address, 0, data.decode('hex'))
        tx.sign(private_key.decode('hex'))
        raw_tx = rlp.encode(tx).encode('hex')
        transaction_hash = json_rpc.eth_sendRawTransaction("0x" + raw_tx)["result"]
    else:
        transaction_hash = json_rpc.eth_sendTransaction(coinbase, to_address=contract_address, data=data, gas=gas, gas_price=gas_price)["result"]
    wait_for_transaction_receipt(json_rpc, transaction_hash)
    print 'Transaction {} for contract {} completed.'.format(name, contract)


def do_assertion(json_rpc, contract, name, params, return_value):
    contract_address = addresses[contract] if contract in addresses else contract
    return_value = addresses[return_value] if return_value in addresses else return_value
    contract_abi = abis[contract]
    translator = ContractTranslator(contract_abi)
    data = translator.encode(name, [addresses[param] if param in addresses else param for param in params]).encode("hex")
    print 'Try to assert return value of {} in contract {}.'.format(name, contract)
    bc_return_val = json_rpc.eth_call(to_address=contract_address, data=data)["result"]
    result_decoded = translator.decode(name, bc_return_val[2:].decode("hex"))
    result_decoded = result_decoded if len(result_decoded) > 1 else result_decoded[0]
    assert result_decoded == return_value[2:]


@click.command()
@click.option('-f', help='File with instructions.')
@click.option('-host', default="localhost", help='Ethereum server host.')
@click.option('-port', default='8545', help='Ethereum server port.')
@click.option('-add_dev_code', default='false', help='Add admin methods.')
@click.option('-contract_dir', default='contracts/', help='Import directory.')
@click.option('-gas', default='4712388', help='Transaction gas.')
@click.option('-gas_price', default='50000000000', help='Transaction gas price.')
@click.option('-private_key', help='Private key as hex to sign transactions.')
def setup(f, host, port, add_dev_code, contract_dir, gas, gas_price, private_key):
    with open(f) as data_file:
        instructions = json.load(data_file)
    json_rpc = EthJsonRpc(host, port)
    coinbase = json_rpc.eth_coinbase()["result"]
    print "Your coinbase: {}".format(coinbase)
    for instruction in instructions:
        print 'Your balance: {} Wei'.format(int(json_rpc.eth_getBalance(coinbase)['result'], 16))
        if instruction["type"] == "deployment":
            deploy_code(
                json_rpc,
                coinbase,
                instruction["file"],
                instruction["constructorParams"] if "constructorParams" in instruction else None,
                instruction["addresses"] if "addresses" in instruction else None,
                add_dev_code == "true",
                contract_dir,
                int(gas),
                int(gas_price),
                private_key
            )
        elif instruction["type"] == "transaction":
            do_transaction(
                json_rpc,
                coinbase,
                instruction["contract"],
                instruction["name"],
                instruction["params"],
                int(gas),
                int(gas_price),
                private_key
            )
        elif instruction["type"] == "assertion":
            do_assertion(
                json_rpc,
                instruction["contract"],
                instruction["name"],
                instruction["params"],
                instruction["return"]
            )
    for contract_name, contract_address in addresses.iteritems():
        print 'Contract {} was created at address {}.'.format(contract_name, contract_address)

if __name__ == '__main__':
    setup()
