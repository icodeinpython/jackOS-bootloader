#include "stdint.h"
#include "io.h"

static void ATA_wait_BSY();
static void ATA_delay_400ns();
static void ATA_wait_DRQ();

static void read_sectors_ATA_28bit_PIO(uint16_t* target, uint32_t LBA, uint8_t sector_count) {
    ATA_wait_BSY();
    // Send 0xE0 for the "master" or 0xF0 for the "slave", ORed with the highest 4 bits of the LBA to port 0x1F6
    outb(0x1F6, 0xE0 | ((LBA >> 24) & 0xF));

    // Send the sectorcount to port 0x1F2
    outb(0x1F2, sector_count);
    
    // Send the low 8 bits of the LBA to port 0x1F3
    outb(0x1F3, (uint8_t)LBA);

    // Send the next 8 bits of the LBA to port 0x1F4
    outb(0x1F4, (uint8_t)(LBA >> 8));
    //next 8
    outb(0x1F5, (uint8_t)(LBA >> 16));
    //Send readsectors command (0x20) to port 0x1F7
    outb(0x1F7, 0x20);
    int count;
    if (sector_count == 0) {
        count = 256;
    } else {
        count = sector_count;
    }
    for (int j = 0; j < count; j++) {
        ATA_delay_400ns();
        ATA_wait_BSY();
        ATA_wait_DRQ();
        for (int i = 0; i < 256; i++)
            target[i] = inw(0x1F0);
        target += 256;
    }
}

void read_sectors_ATA_PIO(void* buf, uint32_t LBA, uint32_t sector_count) {
    while(sector_count) {
        if(sector_count < 256) {
            read_sectors_ATA_28bit_PIO((uint16_t*) buf, LBA, sector_count);
            return;
        } else {
            // read 256 sectors
            read_sectors_ATA_28bit_PIO((uint16_t*) buf, LBA, 0);
            LBA += 256;
            sector_count -= 256;
            buf += 256*512;
        }
    }
}

static int8_t ATA_Identify(uint16_t* target) {
    ATA_wait_BSY();
    // select a target drive by sending 0xA0 for the master drive, or 0xB0 for the slave, to the "drive select" IO port (0x1F6)
    outb(0x1F6, 0xA0);
    // Then set the Sectorcount, LBAlo, LBAmid, and LBAhi IO ports to 0 (port 0x1F2 to 0x1F5)
    outb(0x1F2, 0);
    outb(0x1F3, 0);
    outb(0x1F4, 0);
    outb(0x1F5, 0);
    // Then send the IDENTIFY command (0xEC) to the Command IO port (0x1F7)
    outb(0x1F7, 0xEC);

    ATA_delay_400ns();
    uint8_t status = inb(0x1F7);
    if (status == 0)
        return -1;
    // For any other value: poll the Status port (0x1F7) until bit 7 (BSY, value = 0x80) clears.
    // Because of some ATAPI drives that do not follow spec, at this point you need to check the LBAmid and LBAhi ports (0x1F4 and 0x1F5) 
    // to see if they are non-zero. If so, the drive is not ATA, and you should stop polling.
    while (inb(0x1F7) & 0x80) { // STATUS_BSY -> 0x80
        if (inb(0x1F4) != 0 || inb(0x1F5) != 0)
            return -2;
    };

    if ((inb(0x1F7) & 0x01)) return 3; //STATUS_ERR

    for (int i = 0; i < 256; i++) {
        target[i] = inw(0x1F0);
    }
    return 0;
}

// Get count of all sectors available to address using a 28bit LBA
//
// return: number of 28bit LBA available
uint32_t get_total_28bit_sectors() {
    uint16_t identifier[256];
    uint8_t ret = ATA_Identify(identifier);
    if (ret != 0) {
        return ret;
    }
    // uint16_t 60 & 61 taken as a uint32_t contain the total number of 28 bit LBA addressable sectors on the drive. (If non-zero, the drive supports LBA28.)
    // uint16_t 100 through 103 taken as a uint64_t contain the total number of 48 bit addressable sectors on the drive. (Probably also proof that LBA48 is supported.)
    uint32_t max_sector_28bit_lba = (((uint32_t)identifier[61]) << 16) + identifier[60];
    return max_sector_28bit_lba;
}

// Nedd to add 400ns delays before all the status registers are up to date
// https://wiki.osdev.org/ATA_PIO_Mode#400ns_delays
static void ATA_delay_400ns() {
    inb(0x1F7);
    inb(0x1F7);
    inb(0x1F7);
    inb(0x1F7);
}
static void ATA_wait_BSY() {
    //Wait for BSY to be 0
    while (inb(0x1F7) & 0x80);
}
static void ATA_wait_DRQ() {
    //Wait fot DRQ or ERR to be 1
    while (!(inb(0x1F7) & (0x40 | 0x1)));
}