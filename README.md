# Vera InfluxDB Logger

Sends data to an InfluxDB database from a Vera z-wave controller. 

Install instructions (UI7):
* Uppload D_Influxdb.json, D_Influxdb.xml, I_Influxdb.xml, L_Influxdb.lua and S_Influxdb.xml under: "Apps -> Develop apps -> Luup files"
* Create a device under: "Apps -> Develop apps -> Create device"
	* Device type: urn:schemas-influxdata-com:device:influxdb:1
	* Description: InfluxDB data logger
	* Upnp Device Filename: D_Influxdb.xml
	* Upnp Implementation Filename": I_Influxdb.xml
	* Optionally select a Room for this device
* Reload Luup Engine under: "Settings -> Z-Wave Settings -> Advanced -> Reload Engine (GO)
* Configure settings under: "Devices -> InfluxDB Data Logger -> Settings"
	* Influxdb url: http://<ip/adress>:<port>
	* Influxdb database: <db name>
	* Devices to log (csv): <id1, id2, ...>
* Reload Luup Engine again under: "Settings -> Z-Wave Settings -> Advanced -> Reload Engine (GO)
