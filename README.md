# Driver for the LPS25H Air Pressure / Temperature Sensor

Author: [Tom Byrne](https://github.com/ersatzavian/)

The [LPS25H](http://www.st.com/web/en/resource/technical/document/datasheet/DM00066332.pdf) is a MEMS absolute pressure sensor. This sensor features a large functional range (260-1260hPa) and internal averaging for improved precision.

The LPS25H can interface over I&sup2;C or SPI. This class addresses only I&sup2;C for the time being.

**To add this library to your project, add** `#require "LPS25H.class.nut:1.0.0"` **to the top of your device code**

## Hardware

To use the LPS25H, connect the I2C interface to any of the imp's I2C Interfaces. To see which pins can act as an I2C interface, see the [imp pin mux](https://electricimp.com/docs/hardware/imp/pinmux/) on the Electric Imp Developer Center.

The LPS25H's interrupts are not currently supported by this class, as issues have been observed with using the LPS25H's internal reference pressure registers to generate differential pressure measurements. 

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

The **read()** method reads the pressure in hPa and executes the optional callback passed as its only parameter with the result. The callback takes a single parameter, a table. If an error occurs during the reading, the table passed to the callback will contain a key "err", with a description of the error, and the pressure reading will be null. If the pressure is read successfully, it will be stored in the table with the key "pressure".

If the callback is omitted, **read** executes synchronously and returns a table. As with the asynchrounous flow, the "err" key is present in the table if an error occurs. The pressure is stored with the "pressure" key.

```squirrel
pressureSensor.read(function(result) {
  if ("err" in result) {
    server.error("An Error Occurred: "+result.err);
  } else {
  	server.log(format("Current Pressure: %0.2f hPa", result.pressure));
  }
});
```

```squirrel
local result = pressureSensor.read();
if ("err" in result) {
  server.error("An Error Occurred: "+result.err);
} else {
  server.log(format("Current Pressure: %0.2f hPa", result.pressure));
}
```

### getTemp()

Returns temperature in degrees Celsius.

```squirrel
server.log("Current Temperature: "+pressure.getTemp() + " C");
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

### softReset()

Reset the LPS25H from software. Device will come up disabled.

```squirrel
pressure.softReset();
```

## License

The LPS25H library is licensed under the [MIT License](./LICENSE).
