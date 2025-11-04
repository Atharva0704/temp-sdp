# OAI CN5G for ORANSlice
This page contains information on running OAI 5G core with network slicing enabled.

Two types of OAI CN5G configurations are provided.

- CN with single AMF/SMF/UPF to handle two slices/S-NSSAIs Configuration, under legacy OAI CN (v1.5.1)
- CN with single AMF and two SMFs/UPFs to handle two slices/S-NSSAIs Configuration, under develop branch OAI CN (after v2.0.1)

The first config supports multiple slices configured at gNB/UEs but it enables CN slicing with single SMF and UPF for all network slices.
The second config  provides dedicated core network functions (SMF/UPF) per network slice.

## OAI 5G Core under legacy version

1. Deploy the OAI legacy 5G CN by
```
cd oai-cn5g-legacy
./restart_cn.sh
```

2. Check if the core network works correctly by 
```
docker ps -a
```

##  OAI 5G Core under develop version
1. Pull the OAI 5G core repo
```
git clone https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-fed.git
```
3. Checkout to V2.0.1
```
cd oai-cn5g-fed
git checkout v2.0.1
```
4. Apply the patch
```
git apply <location of the patch file>/dev_oai5gcn.patch
```
5. Start the core-network

For the SMF/UPF per slice setup, do
```
cd docker-compose/
docker compose -f docker-compose-slicing-basic-nrf.yaml up -d
```

For the single SMF/UPF for all slices setup, do 
```
cd docker-compose/
docker compose -f docker-compose-basic-nrf.yaml up -d
```

Check if the core network works correctly by 
```
docker ps -a
```

If there are oai core containers exited a few seconds ago, it indicates the core network is encountering an error.

# OAI gNB Config
Run the gNB with the config file `oai_slicing_usrpX310.conf`. Change the USRP arguments as needed or set to rfsim mode to test the OAI core network.
