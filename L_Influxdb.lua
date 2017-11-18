if(not lul_device) then -- this is for running testing outside vera
	require("luup")
	lul_device = "12"
	InfluxDB_device = lul_device
end

local http=require("socket.http")
local ltn12 = require("ltn12")

-- Task variables
local MSG_CLASS = "InfluxDB"
local taskHandle = -1
local TASK_ERROR = 2
local TASK_ERROR_PERM = -2
local TASK_SUCCESS = 4
local TASK_BUSY = 1

-- Plugin settings
local INFLUXDB_SID = "urn:upnp-influxdata-com:serviceId:InfluxDB1"
local INFLUXDBURL = "InfluxDbUrl";
local INFLUXDBDATABASE = "InfluxDbDatabase";
local INFLUXDBDEVICESTOLOG = "InfluxDbDevicesToLog";

local CALLBACK = "watchVariable"

local function log(text, level)
    luup.log(string.format("%s: %s", MSG_CLASS, text), (level or 25))
end

function variable_watch(service, variable, deviceNo)
	log("Registering watch for " .. variable .. " on device " .. tostring(deviceNo) .. ".")
	luup.variable_watch(CALLBACK, service, variable, deviceNo)
end

local function get_variable(variable, lul_device, default)
	local value, tstamp = luup.variable_get(INFLUXDB_SID, variable, lul_device);
	log("Get variable ".. INFLUXDB_SID .." " .. variable .. " for device " .. tostring(lul_device) .. " returned " .. tostring(value))
	return value or default;
end

local function task(text, mode)
    log("task " .. text)
    if (mode == TASK_ERROR_PERM) then
        taskHandle = luup.task(text, TASK_ERROR, MSG_CLASS, taskHandle)
    else
        taskHandle = luup.task(text, mode, MSG_CLASS, taskHandle)

        -- Clear the previous error, since they're all transient
        if (mode ~= TASK_SUCCESS) then
            luup.call_delay("clearTask", 30, "", false)
        end
    end
end

function clearTask()
    task("Clearing...", TASK_SUCCESS)
end

function initstatus(lul_device)
	log("InfluxDB logger startup("..lul_device..").")
	InfluxDB_device = lul_device
	-- Help prevent race condition
	luup.io.intercept()

	for deviceNo,d in pairs(luup.devices) do
		if d.id ~= "" and shouldDeviceBeWatched(deviceNo) then
			if d.category_num == 2 then
				variable_watch("urn:upnp-org:serviceId:Dimming1", "LoadLevelStatus", deviceNo)
			elseif d.category_num == 3 then
				variable_watch("urn:upnp-org:serviceId:SwitchPower1", "Status", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:EnergyMetering1", "Watts", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:EnergyMetering1", "KWH", deviceNo)
			elseif d.category_num == 4 then
				variable_watch("urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:SecuritySensor1", "ArmedTripped", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:SecuritySensor1", "Armed", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:HaDevice1", "BatteryLevel", deviceNo)
			elseif d.category_num == 5 then
				variable_watch("urn:upnp-org:serviceId:HVAC_UserOperatingMode1", "ModeStatus", deviceNo)
				variable_watch("urn:upnp-org:serviceId:TemperatureSetpoint1_Heat", "CurrentSetpoint", deviceNo)
				variable_watch("urn:upnp-org:serviceId:TemperatureSetpoint1_Cool", "CurrentSetpoint", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:HVAC_ZoneThermostat:1", "CurrentTemperature", deviceNo)
			elseif d.category_num == 7 then
				variable_watch("urn:micasaverde-com:serviceId:DoorLock1", "Target", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:DoorLock1", "Status", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:HaDevice1", "BatteryLevel", deviceNo)
			elseif d.category_num == 16 then
				variable_watch("urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:HaDevice1", "BatteryLevel", deviceNo)
			elseif d.category_num == 17 then
				variable_watch("urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:HaDevice1", "BatteryLevel", deviceNo)
			elseif d.category_num == 18 then
				variable_watch("urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:HaDevice1", "BatteryLevel", deviceNo)
			elseif d.category_num == 18 then
				variable_watch("urn:micasaverde-com:serviceId:EnergyMetering1", "Watts", deviceNo)
				variable_watch("urn:micasaverde-com:serviceId:EnergyMetering1", "KWH", deviceNo)
			end
		end
	end

	writeData(getWriteUrl(), "InfluxDBPlugin.StartPing value=1")

	return true
end

function shouldDeviceBeWatched(deviceNo)
	local returnValue = false
	local devicesToLogString = get_variable(INFLUXDBDEVICESTOLOG, InfluxDB_device, "")

	if devicesToLogString ~= "" then
		devicesToLogTable = splitString(devicesToLogString, ",")
		if valueInTable(devicesToLogTable, tostring(deviceNo)) then
			returnValue = true
		end
	end
	
	return returnValue
end

function splitString(inputString, separator)
	local returnTable={}
	local index = 1
	
	if separator == nil then
		separator = "%s"
	end
	for tmpString in string.gmatch(inputString, "([^"..separator.."]+)") do
		returnTable[index] = string.gsub(tmpString, "%s+", "") -- Remove eventual spaces
		index = index + 1
	end

	if index == 1 then
		returnTable[index] = inputString
	end

	return returnTable
end

function valueInTable(table, value)
	local returnValue = false
	
	for index, currentValue in ipairs(table) do
		if currentValue == value then
			returnValue = true
		end
	end

	return returnValue
end

function writeData(writeUrl, lineProtocol)
	local response_body = {}

	log("Sending request to Influxdb url " .. writeUrl)

	local body, code, headers, status = http.request {
		method = "POST",
		url = writeUrl,
		source = ltn12.source.string(lineProtocol),
		headers =
                {
                    ["Accept"] = "*/*",
                    ["Accept-Language"] = "en-us",
					["Content-Type"] = "application/x-www-form-urlencoded",
					["content-length"] = string.len(lineProtocol)
                },
		sink = ltn12.sink.table(response_body)
	}

	log("Request to influxdb url " .. writeUrl .. " finished with code " .. code);
	if code ~= 204 then
		task("Reqeust to influxdb failed. You need to configure Influx database settings", TASK_ERROR_PERM)
		task("Reqeust to influxdb succeeded", TASK_SUCCESS)
	end

	previousCallCode = code
end

function toInfluxFriendly(text)
	return text:gsub(" ","_")
end

function toInfluxName(lul_device, lul_variable)
	local device = luup.devices[lul_device]
	local room = luup.rooms[device.room_num]
	return toInfluxFriendly(room) .. "." .. toInfluxFriendly(device.description) .. "." .. lul_variable;
end

function getWriteUrl()
	local serverUrl = get_variable(INFLUXDBURL, InfluxDB_device, "http://10.0.0.104:8086")
	local database = get_variable(INFLUXDBDATABASE, InfluxDB_device, "testdb")
	local writeUrl = serverUrl .. "/write?db=" .. database .."&precision=s"
	return writeUrl;
end

function watchVariable(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	log("Watch variable triggered.")
	local lineProtocol = toInfluxName(lul_device, lul_variable) .. " value=" .. tostring(lul_value_new);
	log("Line protocol : " .. lineProtocol)
	writeData(getWriteUrl(), lineProtocol)
end
