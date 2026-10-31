#ifndef FULL_NETWORK_DATA_H
#define FULL_NETWORK_DATA_H

#define WEIGHT_CONV1_BASE 0u
#define WEIGHT_CONV2_BASE 448u
#define WEIGHT_CONV3_BASE 10688u
#define WEIGHT_CLASSIFIER_BASE 22976u

static const uint32_t network_input_words[64] = {
    0xf9faf809u, 0x080dfe00u, 0xfc0108fdu, 0xfb0cfbfeu, 0x0306f100u, 0xfa090008u, 0xff00fe05u, 0x08fe05feu,
    0xfb0806feu, 0xf80603f6u, 0x00fefd01u, 0x01fffcfau, 0x05f8f905u, 0xf8050df6u, 0x02020700u, 0x03050902u,
    0xfa000602u, 0x0c04fd0bu, 0xfcf9f9f5u, 0xf30203fbu, 0xf802fb01u, 0x04f40101u, 0x01f8fd04u, 0x01fb0104u,
    0x08feff07u, 0xf9040bfbu, 0xf801fdf5u, 0xf9f9f9fau, 0xf5effd06u, 0xfc07f8fdu, 0xfef90700u, 0x0103fbffu,
    0x0901fbffu, 0x05040309u, 0x08fa0808u, 0x00040b06u, 0x00fa01ffu, 0x0103f8fcu, 0x0ffa0f03u, 0x0d01fdfcu,
    0xfbf4080bu, 0xfe02fdfau, 0xf703fa0bu, 0x000307f8u, 0xf505fcfbu, 0xfd03f7feu, 0xf601f6fdu, 0x030406feu,
    0x0201fff3u, 0xfd010207u, 0x0103faffu, 0x03f400fcu, 0xfe07fafcu, 0xfafa010au, 0x08f9f9fau, 0xfa080905u,
    0x02050affu, 0xfafdf8fdu, 0x05010110u, 0x01020201u, 0x0af500fdu, 0xfc0504feu, 0x03fa0404u, 0x070102f5u,
};

static const int32_t conv1_bias[32] = {
    -178, -235, -167, -303, -424, -312, -348, -359,
    -384, -156, -200, -444, -696, -380, -485, -224,
    -112, -428, -331, -369, -393, -458, -372, -143,
    -401, -419, -280, -399, -351, -310, -306, -358,
};

static const uint32_t conv1_shift[32] = {
    7u, 7u, 8u, 8u, 8u, 8u, 8u, 8u,
    8u, 7u, 7u, 8u, 8u, 8u, 8u, 8u,
    7u, 8u, 8u, 8u, 8u, 8u, 8u, 8u,
    8u, 8u, 8u, 8u, 8u, 8u, 8u, 8u,
};

static const int32_t conv2_bias[64] = {
    -52, -3307, 1512, -731, 144, 305, 28, -2262,
    7333, 4358, -72, -4024, -1492, 861, -67, -65,
    124, 7926, -2343, 7016, 258, 136, 82, -253,
    -13, 1, -40, 85, -4, 260, -1157, 1374,
    -55, 377, -1, 726, 1640, 682, -230, 3349,
    -9380, -365, 1694, -111, -3159, 35, -1042, 3847,
    30, 2427, -3968, 68, 23, 4075, 1994, 1283,
    -71, 260, -904, -1024, 608, 840, -34, 31,
};

static const uint32_t conv2_shift[64] = {
    11u, 10u, 10u, 10u, 10u, 10u, 11u, 10u,
    10u, 11u, 10u, 10u, 11u, 10u, 11u, 9u,
    10u, 10u, 11u, 10u, 10u, 10u, 11u, 10u,
    11u, 10u, 9u, 11u, 11u, 9u, 10u, 10u,
    11u, 11u, 9u, 11u, 10u, 10u, 9u, 10u,
    10u, 10u, 10u, 10u, 11u, 10u, 10u, 10u,
    10u, 10u, 10u, 10u, 9u, 10u, 10u, 10u,
    10u, 10u, 11u, 10u, 10u, 9u, 10u, 11u,
};

static const int32_t conv3_bias[64] = {
    123, -745, 8, -247, -439, -88, 338, 392,
    -135, 65, 164, 17, -313, -26, 363, -327,
    -437, -482, -377, -350, 18, 364, -427, -111,
    -358, -85, -101, -39, -297, -228, -415, -205,
    108, -1141, -343, 120, 230, -315, -538, -121,
    -402, -163, -141, -82, 731, -242, -468, -676,
    -571, -251, -37, -212, -174, -507, -518, -491,
    -1249, 288, -80, -163, -408, -184, -166, 87,
};

static const uint32_t conv3_shift[64] = {
    7u, 8u, 7u, 7u, 7u, 7u, 7u, 7u,
    7u, 7u, 7u, 6u, 7u, 7u, 8u, 7u,
    7u, 7u, 7u, 8u, 7u, 7u, 7u, 7u,
    7u, 7u, 7u, 7u, 7u, 7u, 8u, 7u,
    7u, 8u, 7u, 7u, 7u, 7u, 7u, 7u,
    7u, 7u, 7u, 7u, 7u, 7u, 7u, 7u,
    7u, 8u, 7u, 7u, 7u, 7u, 7u, 7u,
    8u, 7u, 7u, 7u, 7u, 7u, 7u, 7u,
};

static const int32_t expected_logits[4] = {
    5, -8, 49, -39,
};

static const int32_t classifier_bias[4] = {
    7, -17, 7, 30,
};

#define EXPECTED_POOL1_FNV 0xfdb2efadu
#define EXPECTED_POOL2_FNV 0x9fcdab78u
#define EXPECTED_CONV3_FNV 0x9ab62dc4u
#define EXPECTED_AVERAGE_FNV 0x52ff479au

#endif
