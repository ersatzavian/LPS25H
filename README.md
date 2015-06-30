# Driver for the LPS25H Air Pressure / Temperature Sensor

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [LPS25H](http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf) is a MEMS absolute pressure sensor. This sensor features a large functional range (260-1260hPa) and internal averaging for improved precision.

The LPS25H can interface over I&sup2;C or SPI. This class addresses only I&sup2;C for the time being.

**To add this library to your project, add** `#require "LPS25H.class.nut:1.0.0"` **to the top of your device code**

## Hardware

To use the LPS25H, connect the I2C interface to any of the imp's I2C Interfaces. To see which pins can act as an I2C interface, see the [imp pin mux](https://electricimp.com/docs/hardware/imp/pinmux/) on the Electric Imp Developer Center.

The LPS25H Interrupt Pin behavior can be configured through this class. The corresponding pin on the imp and associated callback are not configured or managed through this class. To use the interrupt pin:

- Connect the LPS25H's "INT1" pin to an imp pin
- Configure the imp pin connected to INT1 as a DIGITAL_IN with your desired callback function
- Use the methods in this class to configure the interrupt behavior as needed

![LPS25H Circuit](./circuit.png)

## Class Usage

### Constructor

The constructor takes two arguments to instantiate the class: a pre-configured I&sup2;C bus and the sensor’s I&sup2;C address. The I&sup2;C address is optional and defaults to 0xB8 (8-bit address).

```squirrel
const LPS25H_ADDR = 0xBA;    // non-default 8-bit I2C Address for LPS25H (SA0 pulled high)

hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
pressureSensor <- LPS25H(hardware.i2c89, LPS25H_ADDR);
```

### Class Methods


### enable(*state*)

Enable (*state* = true) or disable (*state* = false) the LPS25H. The device must be enabled before attempting to read the pressure or temperature.

```squirrel
pressure.enable(true);    // Enable the sensor
```

### read(*callback*)

The **read()** method reads the pressure in hPa and executes the callback passed as its only parameter with the result. The callback takes a single parameter, a table. If an error occurs during the reading, the table passed to the callback will contain a key "err", with a description of the error, and the pressure reading will be null. If the pressure is read successfully, it will be stored in the table with the key "pressure".

```squirrel
pressureSensor.read(function(result) {
  if ("err" in result) {
    server.error("An Error Occurred: "+result.err);
  } else {
  	server.log(format("Current Pressure: %0.2f hPa", result.pressure));
  }
});
```

### getTemp()

Returns temperature in degrees Celsius.

```squirrel
server.log("Current Temperature: "+pressure.getTemp() + " C");
```

### configureInterrupt(*enable*, [*threshold*, *options*])

This method configures the interrupt pin driver, threshold, and sources.

- *enable* is a required boolean parameter. Set true to enable the interrupt pin.
- *threshold* is an optional parameter, to set the interrupt threshold pressure. This threshold applies regardless of whether the interrupt is configured to fire on high differential pressure or low differential pressure. The threshold is expressed in hectopascals (hPa).
- *options* is an optional bitfield which allows the pin driver and interrupt condition to be configured by OR'ing together the appropriate flags:

| Constant | Description | Notes |
| -------- | ----------- | ----- |
| INT_ACTIVEHIGH | Interrupt pin active-high | Interrupt pin is active-low by default|
| INT_PUSHPULL | Interrupt pin driver push-pull | Interrupt pin driver open-drain by default |
| INT_LATCH | Interrupts latched | Clear latched interrupts by calling getInterruptSrc() |
| INT_LOW_PRESSURE | Interrupt on pressure below threshold | |
| INT_HIGH_PRESSURE | Interrupt on pressure above threshold | |

```squirrel
// Enable interrupt, configure as push-pull, active-high, latched. Fire interrupt if pressure > 800 hPa
pressureSensor.configureInterrupt(true, 800, INT_ACTIVEHIGH | INT_PUSHPULL | INT_LATCH | INT_HIGH_PRESSURE);
```

```squirrel
// Enable interrupt, configure as open-drain, active-low, latched. Fire interrupt if pressure < 760 hPa
pressureSensor.configureInterrupt(ture, 760, INT_LATCH | INT_LOW_PRESSURE);
```

### getInterruptSrc() 

Determine what caused an interrupt, and clear latched interrupt. This method returns an integer which can be compared to the following flags to determine the interrupt status and source. Latched interrupts are cleared as a side effect.

| Constant | Description | Notes |
| -------- | ----------- | ----- |
| INT_ACTIVE | Set if an interrupt is currently active or latched | |
| INT_HIGH_PRESSURE_ACTIVE | Set if the active or latched interrupt was due to a high pressure event | |
| INT_LOW_PRESSURE_ACTIVE | Set if the active or latched interrupt was due to a low pressure event | |

```squirrel
// Check the interrupt source and clear the latched interrupt
local intSrc = pressureSensor.getInterruptSrc();
if (intSrc & LPS25H.INT_ACTIVE) {
  // interrupt is active
  if (intSrc & LPS25H.INT_HIGH_PRESSURE_ACTIVE) {
    server.log("High Pressure Interrupt Occurred!");
  } 
  if (intSrc & LPS25H.INT_LOW_PRESSURE_ACTIVE) {
    server.log("Low Pressure Interrupt Occurred!");
  }
} else {
  server.log("No Interrupts Active");
}
```

### setPressNpts(*numberOfReadings*)

Set the number of readings taken and then internally averaged to produce a pressure result. The value provided will be rounded up to the nearest valid value: 8, 32 and 128.

```squirrel
// Fastest readings, lowest precision

pressure.setPressNpts(8);

// Slowest readings, highest precision

pressure.setPressNpts(128);
```

### setTempNpts(*numberOfReadings*)

Set the number of readings taken and internally averaged to produce a temperature result. The value provided will be rounded up to the nearest valid value: 8, 16, 32 and 64.

```squirrel
// Fastest readings, lowest precision

pressure.setTempNpts(8);

// Slowest readings, highest precision

pressure.setTempNpts(64);
```

### setFifoEnable(*state*)

Enable (*state* = 1) or disable (*state* = 0) the internal FIFO for continuous pressure and temperature readings. Disabled by default.

```squirrel
// Enable internal FIFO for continuous pressure readings

pressure.setFifoEnable(1);
```

### getReferencePressure()

Get the internal offset pressure set in the factory. Returns a raw value in the same units as the raw pressure registers (hPa * 4096)

```squirrel
server.log("Internal Reference Pressure Offset = " + pressure.getReferencePressure());
```

### softReset()

Reset the LPS25H from software. Device will come up disabled.

```squirrel
pressure.softReset();
```

### getRawPressure()

Returns the raw value of PRESS_OUT_H, PRESS_OUT_L and PRESS_OUT_XL. Units are hPa * 4096.

## License

The LPS25H library is licensed under the [MIT License](./LICENSE).
