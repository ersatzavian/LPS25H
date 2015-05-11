# Driver for the LPS25H Air Pressure / Temperature Sensor

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [LPS25H](http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf) is a MEMS absolute pressure sensor. This sensor features a large functional range (260-1260hPa) and internal averaging for improved precision.

The LPS25HTR can interface over I&sup2;C or SPI. This class addresses only I&sup2;C for the time being.

## Hardware

The LPS25H should be connected as follows:

![LPS25H Circuit](./circuit.png)

## Class Usage

### Constructor

The constructor takes two arguments to instantiate the class: a pre-configured I&sup2;C bus and the sensor’s I&sup2;C address.

```squirrel
const LPS25H_ADDR = 0xB8    // 8-bit I2C Address for LPS25H (0x5C on datasheet)

hardware.i2c89.configure(CLOCK_SPEED_400_KHZ)
pressure <- LPS25H(hardware.i2c89, LPS25H_ADDR)

```

### Class Methods

### read(*callback*)

The **read()** method reads the pressure in hPa and executes the callback passed as its only parameter with the result. The callback takes a single parameter: the pressure reading (float).

```squirrel
pressure.read(function(pressureHPa) {
  server.log(pressureHPa + " hPa")
})
```

### getTemp()

Returns temperature in degrees Celsius.

```squirrel
server.log(pressure.getTemp() + "C")
```

### softReset()

Reset the LPS25H from software. Device will come up disabled.

```squirrel
pressure.softReset()
```

### enable(*state*)

Enable (*state* = 1) or disable (*state* = 0) the LPS25H. The device must be enabled before attempting to read the pressure or temperature.

```squirrel
pressure.enable(1)    // Enable the sensor
```

### getReferencePressure()

Get the internal offset pressure set in the factory. Returns a raw value in the same units as the raw pressure registers (hPa * 4096)

```squirrel
server.log("Internal Reference Pressure Offset = " + pressure.getReferencePressure())
```

### setPressNpts(*numberOfReadings*)

Set the number of readings taken and then internally averaged to produce a pressure result. The value provided will be rounded up to the nearest valid value: 8, 32 and 128.

```squirrel
// Dastest readings, lowest precision

pressure.setPressNpts(8)

// Slowest readings, highest precision

pressure.setPressNpts(128)
```

### setTempNpts(*numberOfReadings*)

Set the number of readings taken and internally averaged to produce a temperature result. The value provided will be rounded up to the nearest valid value: 8, 16, 32 and 64.

```squirrel
// Dastest readings, lowest precision

pressure.setTempNpts(8)

// Slowest readings, highest precision

pressure.setTempNpts(64)
```

### setIntEnable(*state*)

Enable (*state* = 1) or disable (*state* = 0) the LPS25H’s interrupt pin.

```squirrel
// Enable interrupts on the LPS25H's interrupt pin

pressure.setIntEnable(1)
```

### setFifoEnable(*state*)

Enable (*state* = 1) or disable (*state* = 0) the internal FIFO for continuous pressure and temperature readings. Disabled by default.

```squirrel
// Enable internal FIFO for continuous pressure readings

pressure.setFifoEnable(1)
```

### setIntActivehigh(*state*)

Set the LPS25H’s interrupt polarity: `1` configures the interrupt pin to be active-high; `0` configures the pin for active-low.

```squirrel
// Set interrupt pin to active-high

pressure.setIntActivehigh(1)

// Set interrupt pin to active-low

pressure.setIntActivehigh(0)
```

### setIntPushpull(*state*)

Select between push-pull (*state* = 1) and open-drain (*state* = 0) states for the interrupt pin.

```squirrel
// Set interrupt pin to push-pull

pressure.setIntPushpull(1)

// Set interrupt pin to open-drain

pressure.setIntPushpull(0)
```

### setIntConfig(*latch*, *differentialPressureLow*, *differentialPressureHigh*)

Configure the sources for the interrupt pin:

- *latch* set `1` to require that the interrupt source be read before the interrupt pin is de-asserted
- *differentialPressureLow* set `1` to throw interrupts on differential pressure below the set threshold
- *differentialPressureHigh* set `1` to throw interrupts on differential pressure above the set threshold

```squirrel
// Configure interrupt pin to assert on pressure above threshold and latch until cleared

pressure.setIntConfig(1, 0, 1)
```
The interrupt source is stored in the INT_SOURCE register (0x25). To clear a latched interrupt or find out why the interrupt pin was asserted, read this register and check bits [2:0]:

| bit | meaning |
| --- | ------- |
| 2 | interrupt is currently active |
| 1 | differential pressure low |
| 0 | differential pressure high |

```squirrel
// Read interrupt source register to see why interrupt was triggered

local val = pressure.read(LPS25H.INT_SOURCE, 1)[0]

if (val & 0x02) 
{
	server.log("Differential Pressure Low Event Occurred")
}

if (val & 0x01) 
{
	server.log("Differential Pressure High Event Occurred")
}
```

### setPressThresh(*threshold*)

Set the threshold value (integer) for pressure interrupts. Units are hPa * 4096.

```squirrel
// Set threshold pressure to 1000 mBar

local thresh = 1000 * 4096
pressure.setPressThresh(thresh)
```

### getRawPressure()

Returns the raw value of PRESS_OUT_H, PRESS_OUT_L and PRESS_OUT_XL. Units are hPa * 4096.

## License

The LPS25H library is licensed under the [MIT License](./LICENSE).
