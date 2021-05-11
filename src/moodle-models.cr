require "json"

class Moodle::Resp(T)
    include JSON::Serializable
    
    property error : Bool | String
    property data : T
end

class Moodle::Events
    include JSON::Serializable
    
    property events : Array(Moodle::Event)
end

class Moodle::Event
    include JSON::Serializable
    
    property name : String
    property description : String
    property eventtype : String

    @[JSON::Field(converter: Time::EpochConverter)]
    property timestart : Time

    @[JSON::Field(converter: Time::EpochConverter)]
    property timeduration : Time

    @[JSON::Field(converter: Time::EpochConverter)]
    property timesort : Time

    @[JSON::Field(converter: Time::EpochConverter)]
    property timemodified : Time

    property canedit : Bool
    property candelete : Bool
    property deleteurl : String
    property editurl : String
    property viewurl : String
    property formattedtime : String
    property isactionevent : Bool
    property iscourseevent : Bool
    property iscategoryevent : Bool
    property url : String
    property course : Moodle::Course
    property action : Moodle::EventAction
end

class Moodle::Course
    include JSON::Serializable
    
    property fullname : String
    property shortname : String
    property summary : String

    @[JSON::Field(converter: Time::EpochConverter)]
    property startdate : Time

    @[JSON::Field(converter: Time::EpochConverter)]
    property enddate : Time

    property viewurl : String
    property coursecategory : String
    property visible : Bool
    property hidden : Bool
end

class Moodle::EventAction
    include JSON::Serializable
    
    property name : String
    property url : String
    property itemcount : UInt32
    property actionable : Bool
    property showitemcount : Bool
end

class Moodle::Req(T)
    include JSON::Serializable
    
    property index
    property methodname : String
    property args : T

    def initialize(@methodname, @args, @index = 0)
    end
end

module Moodle::MethodNames
    EVENTS_BY_TIMESORT = "core_calendar_get_action_events_by_timesort"
end

class Moodle::EventsByTimesortArgs
    include JSON::Serializable
    
    property limitnum : UInt32

    @[JSON::Field(converter: Time::EpochConverter)]
    property timesortfrom : Time

    @[JSON::Field(converter: Time::EpochConverter)]
    property timesortto : Time | Nil

    property limittononsuspendedevents

    def initialize(@limitnum, @timesortfrom, @timesortto = Nil, @limittononsuspendedevents = true)
    end
end