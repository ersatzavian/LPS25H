// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Driver class for the LPS25H Air Pressure Sensor
// http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf

class LPS25H {
    static MEAS_TIME_SECONDS = 0.5; // seconds; time to complete pressure conversion

    static REF_P_XL        = 0x08;
    static REF_P_L         = 0X09;
    static REF_P_H         = 0x0A;
    static WHO_AM_I        = 0x0F;
    static RES_CONF        = 0x10;
    static CTRL_REG1       = 0x20;
    static CTRL_REG2       = 0x21;
    static CTRL_REG3       = 0x22;
    static CTRL_REG4       = 0x23;
    static INT_CFG         = 0x24;
    static INT_SOURCE      = 0x25;
    static STATUS_REG      = 0x27;
    static PRESS_OUT_XL    = 0x28;
    static PRESS_OUT_L     = 0x29;
    static PRESS_OUT_H     = 0x2A;
    static TEMP_OUT_L      = 0x2B;
    static TEMP_OUT_H      = 0x2C;
    static FIFO_CTRL       = 0x2E;
    static FIFO_STATUS     = 0x2F;
    static THS_P_L         = 0x30;
    static THS_P_H         = 0x31;
    static RPDS_L          = 0x39;
    static RPDS_H          = 0x3A;

    // interrupt bitfield 
    static INT_HIGH_PRESSURE_ACTIVE = 0x01;
    static INT_LOW_PRESSURE_ACTIVE  = 0x02;
    static INT_ACTIVE               = 0x04;
    static INT_ACTIVEHIGH           = 0x08;
    static INT_PUSHPULL             = 0x10;
    static INT_LATCH                = 0x20;
    static INT_LOW_PRESSURE         = 0x40;
    static INT_HIGH_PRESSURE        = 0x80;

    _i2c        = null;
    _addr       = null;

    _referencePressure = null;

    // -------------------------------------------------------------------------
    constructor(i2c, addr = 0xB8) {
        _i2c = i2c;
        _addr = addr;

        init();
    }

    // -------------------------------------------------------------------------
    function init() {
        enable(1);
        _referencePressure = getReferencePressure();
        enable(0);
    }

    // -------------------------------------------------------------------------
    function _twosComp(value, mask) {
        value = ~(value & mask) + 1;
        return -1 * (value & mask);
    }

    // -------------------------------------------------------------------------
    function _readReg(reg, numBytes) {
        local result = _i2c.read(_addr, reg.tochar(), numBytes);
        if (result == null) {
            throw "I2C read error: " + _i2c.readerror();
        }
        return result;
    }

    // -------------------------------------------------------------------------
    function _writeReg(reg, ...) {
        local s = reg.tochar();
        foreach (b in vargv) {
            s += b.tochar();
        }
        local result = _i2c.write(_addr, s);
        if (result) {
            throw "I2C write error: " + result;
        }
        return result;
    }

    // -------------------------------------------------------------------------
    function getDeviceID() {
        return _readReg(WHO_AM_I, 1);
    }

    // -------------------------------------------------------------------------
    function enable(state) {
        local val = _readReg(CTRL_REG1, 1)[0];
        if (state) {
            val = val | 0x80;
        } else {
            val = val & 0x7F;
        }
        _writeReg(CTRL_REG1, val);
    }

    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a pressure result
    // Selector field is 2 bits
    function setPressNpts(npts) {
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 32) {
            // Average 32 readings
            npts = 0x01
        } else if (npts <= 128) {
            // Average 128 readings
            npts = 0x02;
        } else {
            // Average 512 readings
            npts = 0x03;
        }
        local val = _readReg(RES_CONF, 1)[0];
        local res = _writeReg(RES_CONF, (val & 0xFC) | npts);
    }

    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a temperature result
    // Selector field is 2 bits
    function setTempNpts(npts) {
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 16) {
            // Average 16 readings
            npts = 0x01
        } else if (npts <= 32) {
            // Average 32 readings
            npts = 0x02;
        } else {
            // Average 64 readings
            npts = 0x03;
        }
        local val = _readReg(RES_CONF, 1);
        local res = _writeReg(RES_CONF, (val & 0xF3) | (npts << 2));
    }

    // -------------------------------------------------------------------------
    function configureInterrupt(enable, threshold = null, options = 0) {
        
        // set the enable -----------------------------------------------------
        local val = _readReg(CTRL_REG1, 1)[0];
        if (enable) {
            val = val | 0x08;
        } else {
            val = val & 0xF7;
        }
        _writeReg(CTRL_REG1, val & 0xFF);

        // set the threshold, if it was given ---------------------------------
        if (threshold != null) {
            threshold = threshold * 4096;
            _writeReg(THS_P_H, (threshold & 0xFF00) >> 8);
            _writeReg(THS_P_L, threshold & 0xFF);
        }

        // check and set the options ------------------------------------------

        // interrupt pin active-high (active-low by default)
        val = _readReg(CTRL_REG3, 1)[0];
        if (options & INT_ACTIVEHIGH) {
            val = val & 0x7F;
        } else {
            val = val | 0x80;
        }
        // interrupt pin push-pull (open drain by default)
        if (options & INT_PUSHPULL) {
            val = val & 0xBF;
        } else {
            val = val | 0x40;
        }
        _writeReg(CTRL_REG3, val & 0xFF);

        // interrupt latched
        val = _readReg(CTRL_REG1, 1)[0];
        if (options & INT_LATCH) {
            val = val | 0x04;
        }
        // interrupt on low differential pressure
        if (options & INT_LOW_PRESSURE) {
            val = val & 0x02;
        }
        // interrupt on high differential pressure
        if (options & INT_HIGH_PRESSURE) {
            val = val | 0x01;
        }
        _writeReg(CTRL_REG1, val & 0xFF);
    }

    // -------------------------------------------------------------------------
    function getInterruptSrc() {
        val = _readReg(INT_SOURCE, 1)[0];
    }

    // -------------------------------------------------------------------------
    function setFifoEnable(state) {
        local val = _readReg(CTRL_REG2, 1)[0];
        if (state) {
            val = val | 0x40;
        } else {
            val = val & 0xAF;
        }
        local res = _writeReg(CTRL_REG2, val & 0xFF);
    }

    // -------------------------------------------------------------------------
    function softReset(state) {
        local res = _writeReg(CTRL_REG2, 0x04);
    }

    // -------------------------------------------------------------------------
    function getReferencePressure() {
        local low   = _readReg(REF_P_XL, 1);
        local mid   = _readReg(REF_P_L, 1);
        local high  = _readReg(REF_P_H, 1);
        return ((high[0] << 16) | (mid[0] << 8) | low[0]);
    }

    // -------------------------------------------------------------------------
    // Returns raw pressure register values
    function getRawPressure() {
        local low   = _readReg(PRESS_OUT_XL, 1);
        local mid   = _readReg(PRESS_OUT_L, 1);
        local high  = _readReg(PRESS_OUT_H, 1);
        return ((high[0] << 16) | (mid[0] << 8) | low[0]);
    }

    // -------------------------------------------------------------------------
    function read(cb = null) {
        // This method takes some time, and so is async-only
        if (cb == null) {
            return {"error": "LPS25H read requires a callback function"};
        }
        // try/catch so errors thrown by I2C methods can be handed to the callback
        // instead of just thrown again
        try {
            // Start a one-shot measurement
            _writeReg(CTRL_REG2, 0x01);
            // Read the reference pressure
            local referencePressure = getReferencePressure();
            // Get pressure in HPa
            imp.wakeup(MEAS_TIME_SECONDS, function() {
                local pressure = (getRawPressure() - referencePressure) / 4096.0;
                cb({"pressure": pressure});
            }.bindenv(this));
        } catch (err) {
            cb({"error": err, "pressure": null});
        }

    }

    // -------------------------------------------------------------------------
    function getTemp() {
        enable(1);
        local temp_l = _readReg(TEMP_OUT_L, 1)[0];
        local temp_h = _readReg(TEMP_OUT_H, 1)[0];
        enable(0);

        local temp_raw = (temp_h << 8) | temp_l;
        if (temp_raw & 0x8000) {
            temp_raw = _twosComp(temp_raw, 0xFFFF);
        }
        return (42.5 + (temp_raw / 480.0));
    }
}
