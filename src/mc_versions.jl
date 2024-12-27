using CEnum

@cenum(
    MCVersion::UInt8,
    MC_UNDEF = 0,
    MC_B1_7 = 1,
    MC_B1_8 = 2,
    MC_1_0_0 = 3, MC_1_0 = 3,
    MC_1_1_0 = 4, MC_1_1 = 4,
    MC_1_2_5 = 5, MC_1_2 = 5,
    MC_1_3_2 = 6, MC_1_3 = 6,
    MC_1_4_2 = 7, MC_1_4 = 7,
    MC_1_5_2 = 8, MC_1_5 = 8,
    MC_1_6_4 = 9, MC_1_6 = 9,
    MC_1_7_10 = 10, MC_1_7 = 10,
    MC_1_8_9 = 11, MC_1_8 = 11,
    MC_1_9_4 = 12, MC_1_9 = 12,
    MC_1_10_2 = 13, MC_1_10 = 13,
    MC_1_11_2 = 14, MC_1_11 = 14,
    MC_1_12_2 = 15, MC_1_12 = 15,
    MC_1_13_2 = 16, MC_1_13 = 16,
    MC_1_14_4 = 17, MC_1_14 = 17,
    MC_1_15_2 = 18, MC_1_15 = 18,
    MC_1_16_1 = 19,
    MC_1_16_5 = 20, MC_1_16 = 20,
    MC_1_17_1 = 21, MC_1_17 = 21,
    MC_1_18_2 = 22, MC_1_18 = 22,
    MC_1_19_2 = 23,
    MC_1_19 = 24,
    MC_1_20 = 25,
    MC_1_21 = 26,
    MC_NEWEST = 26,
)

# To be nice with the editor because this little child is lost because of the macro :(
MCVersion = MCVersion
