// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// Driver class for the LPS25H Air Pressure Sensor
// http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf

class LPS25H {

    static version = [2,0,0];

    static MAX_MEAS_TIME_SECONDS = 0.5; // seconds; time to complete one-shot pressure conversion

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

    static PRESSURE_SCALE = 4096.0;
    static REFERENCE_PRESSURE_SCALE = 16.0;
    static MAX_REFERENCE_PRESSURE = 65534;

    // interrupt bitfield 
    static INT_HIGH_PRESSURE_ACTIVE = 0x01;
    static INT_LOW_PRESSURE_ACTIVE  = 0x02;
    static INT_ACTIVE               = 0x04;
    static INT_ACTIVELOW            = 0x08;
    static INT_OPENDRAIN            = 0x10;
    static INT_LATCH                = 0x20;
    static INT_LOW_PRESSURE         = 0x40;
    static INT_HIGH_PRESSURE        = 0x80;

    _i2c        = null;
    _addr       = null;

    // -------------------------------------------------------------------------
    constructor(i2c, addr = 0xB8) {
        _i2c = i2c;
        _addr = addr;
    }

    // -------------------------------------------------------------------------
    function getDeviceID() {
        return _readReg(WHO_AM_I, 1);
    }

    // -------------------------------------------------------------------------
    function enable(state) {
        local val = _readReg(CTRL_REG1, 1);
        if (val == null) {
            throw "I2C Error";
        } else {
            val = val[0];
        }
        if (state) {
            val = val | 0x80;
        } else {
            val = val & 0x7F;
        }
        _writeReg(CTRL_REG1, val);
    }

    // -------------------------------------------------------------------------
    function setDataRate(datarate) {
        local actualRate = 0.0;
        if (datarate <= 0) {
            datarate = 0x00;
        } else if (datarate <= 1) {
            actualRate = 1.0;
            datarate = 0x01;
        } else if (datarate <= 7) {
            actualRate = 7.0;
            datarate = 0x02;
        } else if (datarate <= 12.5) {
            actualRate = 12.5;
            datarate = 0x03;
        } else {
            actualRate = 25.0;
            datarate = 0x04;
        }
        local val = (_readReg(CTRL_REG1, 1)[0] & 0x8F);
        _writeReg(CTRL_REG1, (val | (datarate << 4)));
        return actualRate;
    }
    
    // -------------------------------------------------------------------------
    function getDataRate() {
        local val = (_readReg(CTRL_REG1, 1)[0] & 0x70) >> 4;
        if (val == 0) {
            return 0.0;
        } else if (val == 0x01) {
            return 1.0;
        } else if (val == 0x02) {
            return 7.0;
        } else if (val == 0x03) {
            return 12.5;
        } else {
            return 25.0;
        }
    }

    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a pressure result
    // Selector field is 2 bits
    function setPressNpts(npts) {
        local actualNpts = 8;
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 32) {
            // Average 32 readings
            actualNpts = 32;
            npts = 0x01
        } else if (npts <= 128) {
            // Average 128 readings
            actualNpts = 128;
            npts = 0x02;
        } else {
            // Average 512 readings
            actualNpts = 512;
            npts = 0x03;
        }
        local val = _readReg(RES_CONF, 1)[0];
        local res = _writeReg(RES_CONF, (val & 0xFC) | npts);
        return actualNpts;
    }

    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a temperature result
    // Selector field is 2 bits
    function setTempNpts(npts) {
        local actualNpts = 8;
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 16) {
            // Average 16 readings
            actualNpts = 16;
            npts = 0x01
        } else if (npts <= 32) {
            // Average 32 readings
            actualNpts = 32;
            npts = 0x02;
        } else {
            // Average 64 readings
            actualNpts = 64;
            npts = 0x03;
        }
        local val = _readReg(RES_CONF, 1);
        local res = _writeReg(RES_CONF, (val & 0xF3) | (npts << 2));
        return actualNpts;
    }

    // ------------------------------------ena-------------------------------------
    function configureInterrupt(enable, threshold = null, options = 0) {
        
        // Datasheet recommends setting threshold before enabling/disabling int gen
        // set the threshold, if it was given ---------------------------------
        if (threshold != null) {
            threshold = threshold * 16;
            _writeReg(THS_P_H, (threshold & 0xFF00) >> 8);
            _writeReg(THS_P_L, threshold & 0xFF);
        }
        
        // check and set the options ------------------------------------------

        // interrupt pin active-high (active-low by default)
        local val = _readReg(CTRL_REG3, 1)[0];
        if (options & INT_ACTIVELOW) {
            val = val | 0x80;
        } else {
            val = val & 0x7F;
        }
        // interrupt pin push-pull (open drain by default)
        if (options & INT_OPENDRAIN) {
            val = val | 0x40;
        } else {
            val = val & 0xBF;
        }
        // pressure low and pressure high interrupts routed to pin
        if (enable) {
            val = val | 0x03;
        } else {
            val = val & 0xFA;
        }
        _writeReg(CTRL_REG3, val & 0xFF);

        // interrupt latched
        val = _readReg(INT_CFG, 1)[0] & 0xF8;
        if (options & INT_LATCH) {
            val = val | 0x04;
        }
        // interrupt on low differential pressure
        if (options & INT_LOW_PRESSURE) {
            val = val | 0x02;
        }
        // interrupt on high differential pressure
        if (options & INT_HIGH_PRESSURE) {
            val = val | 0x01;
        }
        _writeReg(INT_CFG, val & 0xFF);
        
                
        // set the enable -----------------------------------------------------
        val = _readReg(CTRL_REG1, 1)[0];
        if (enable) {
            val = val | 0x08;
        } else {
            val = val & 0xF7;
        }
        _writeReg(CTRL_REG1, val & 0xFF);
    }

    // -------------------------------------------------------------------------
    function getInterruptSrc() {
        local val = _readReg(INT_SOURCE, 1)[0];
        local intSrcTable = {"int_active": false, "high_pressure": false, "low_pressure": false};
        if (val & 0x04) { intSrcTable.int_active = true; }
        if (val & 0x02) { intSrcTable.low_pressure = true; }
        if (val & 0x01) { intSrcTable.high_pressure = true; }
        return intSrcTable;
    }

    // -------------------------------------------------------------------------
    function softReset() {
        _writeReg(CTRL_REG2, 0x84);
    }

    // -------------------------------------------------------------------------
    function getReferencePressure() {
        local low   = _readReg(RPDS_L, 1);
        local high  = _readReg(RPDS_H, 1);
        local val = ((high[0] << 8) | low[0]);
        if (val & 0x8000) { val = _twosComp(val, 0x7FFF); }
        return (val * 1.0) / REFERENCE_PRESSURE_SCALE;
    }
    
    // -------------------------------------------------------------------------
    function setReferencePressure(val) {
        val = (val * REFERENCE_PRESSURE_SCALE).tointeger();
        if (val < 0) { val = _twosComp(val, 0x7FFF); }
        server.log(format("ref: 0x%04X", val));
        _writeReg(RPDS_H, (val & 0xFF00) >> 8);
        _writeReg(RPDS_L, (val & 0xFF));
    }

    // -------------------------------------------------------------------------
    function read(cb = null) {
        // try/catch so errors thrown by I2C methods can be handed to the callback
        // instead of just thrown again
        try {
            // if we're not in continuous-conversion mode
            local datarate = getDataRate();
            local meas_time = 0;
            if (datarate == 0) {
                // Start a one-shot measurement
                _writeReg(CTRL_REG2, 0x01);
                meas_time = MAX_MEAS_TIME_SECONDS;
            } else {
                meas_time = 1.0 / datarate;
            }
            
            // Get pressure in HPa
            if (cb == null) {
                local pressure = _getPressure() + getReferencePressure();
                return {"pressure_": pressure};
            } else {
                imp.wakeup(meas_time, function() {
                    local pressure = _getPressure() + getReferencePressure();
                    cb({"pressure": pressure});
                }.bindenv(this));
            }
        } catch (err) {
            if (cb == null) {
                return {"error": err, "pressure": null};
            } else {
                imp.wakeup(0, function() {
                    cb({"error": err, "pressure": null})
                });
            }
        }
    }

    // -------------------------------------------------------------------------
    function getTemp() {
        local temp_l = _readReg(TEMP_OUT_L, 1)[0];
        local temp_h = _readReg(TEMP_OUT_H, 1)[0];

        local temp_raw = (temp_h << 8) | temp_l;
        if (temp_raw & 0x8000) {
            temp_raw = _twosComp(temp_raw, 0x7FFF);
        }
        return (42.5 + (temp_raw / 480.0));
    }

    // ------------------ PRIVATE METHODS -------------------------------------//

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
    // Returns raw pressure register values
    function _getPressure() {
        local low   = _readReg(PRESS_OUT_XL, 1);
        local mid   = _readReg(PRESS_OUT_L, 1);
        local high  = _readReg(PRESS_OUT_H, 1);
        local raw = ((high[0] << 16) | (mid[0] << 8) | low[0]);
        if (raw & 0x800000) { raw = _twosComp(raw, 0x7FFFFF); }
        return (raw * 1.0) / PRESSURE_SCALE;
    }
}