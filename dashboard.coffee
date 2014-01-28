
TRELLO_BOARDS = ['UsP5zlas']
REFRESH_INTERVAL = 60000
AUTOREFRESH_HOURS = 6
GCAL_FEED_URL_LS_KEY = 'arachnysDashboardFeedUrl'
PIPEDRIVE_API_KEY_LS_KEY = 'arachnysPipedriveApiKey'
PIPEDRIVE_API_BASE = 'https://api.pipedrive.com/v1'
NAME_TO_INITIALS_MAPPING =
    "David Buxton": "DB"
    "Mike Cerillo": "MC"
    "Lynn Petesch": "L"
    "Aaron Tanner": "AT"
    "Hollie Tu": "HT"
    "Enric Castane": "EC"
    "Minna Cowper-Coles": "MCC"
    "Board Members": "BM"
    "david": "DB"
    "harry": "HW"
    "matthew": "MB"
    "mateusz": "MK"
    "james": "JP"

window.calendarEvents = {}

# This is why we should do this with models
window.organizationMembers = {}
window.organizationMembersInitials = {}

window.boardLists = {}


# Models
List = Backbone.Model.extend
    defaults:
        id: null
        url: null
        name: "No name"

User = Backbone.Model.extend
    defaults:
        initials: "NI"
        name: "No name"
        avatarHash: null

Card = Backbone.Model.extend
    defaults:
        id: null
        title: "No title"
        url: "#"
        start: null
        end: null
        class: "card"
        listId: null
        complete: false
        userIds: []

    inPast: () ->
        now = new Date()
        startDate = new Date(this.get('start'))
        if not startDate?
            return false
        return (now.getTime() - startDate.getTime()) > 0

    viewEvent: () ->
        window.location.href = url

# Collections
Cards = Backbone.Collection.extend
    model: Card

Users = Backbone.Collection.extend
    model: User

Lists = Backbone.Collection.extend
    model: List

    initialize: () ->
        @cards = new Cards

users = new Users

lists = new Lists

calendarCards = new Cards

CardView = Backbone.View.extend
    tagname: "li"
    template: _.template $('#item-template').html()
    events:
        click: "viewEvent"
    initialize: () ->
        @listenTo(@model, 'change', @render)
    render: () ->
        @$el.html(@template(@model.toJSON()))
        return @

# We don't need a view for calendar as that's handled by lib
# We do for other things though

CompleteCardsView = Backbone.View.extend
    el: $("#completed-cards")
    initialize: () ->
        @listenTo(CalendarCards, 'add', @addOne)
        @listenTo(CalendarCards, 'reset', @addAll)

    addOne: (card) ->
        if card.complete
            view = new CardView
                model: card
            @$("#completed-cards").append(view.render().el)

    addAll: () ->
        complete = new Cards(CalendarCards.where({complete: true}))
        complete.each(@addOne, @)


window.onAuthorize = () ->
    updateLoggedIn()
    $("#output").empty()
    loadInitialData(getBoardCards)

getMonday = (d) ->
    d = new Date(d)
    day = d.getDay()
    diff = d.getDate() - day + (day == 0 ? -6:1)
    return new Date(d.setDate(diff))

getBoardCards = (callback) ->
    getCompletedCards()
    $noDueDate = $('#no-due-date').empty()
    $('<h4>No due date/in past</h4>').appendTo($noDueDate)
    $('<div>').text('Loading...').appendTo($noDueDate)
    now = new Date()
    firstOfWeek = getMonday(now)
    $.each TRELLO_BOARDS, (idx, boardId) ->
        Trello.get "boards/#{boardId}/cards?filter=visible", (cards) ->
            $.each cards, (ix, card) ->
                calendarCards.create
                    id: card.url
                    title: card.name
                    members: card.userIds
                    listId: card.idList
                    url: card.url
                    start: new Date(card.due).getTime()
                    end: new Date(card.due).getTime()
                    complete: false


                metadata = formatCardMetaData(card.idMembers)
                boardName = window.boardLists[card.idList].name
                if boardName == "Complete"
                    cls = "event-success event-fade #{metadata.avatarString} #{if metadata.avatarString != '' then 'event-large' else ''}"
                else if boardName == "In progress"
                    cls = "event-progress #{metadata.avatarString} #{if metadata.avatarString != '' then 'event-large' else ''} #{if inPast(card.due, now) then 'event-in-past' else ''}"
                else
                    cls = "event-not-started #{metadata.avatarString} #{if metadata.avatarString != '' then 'event-large' else ''} #{if inPast(card.due, now) then 'event-in-past' else ''}"
                dueDate = new Date(card.due).getTime()
                if card.due and dueDate > firstOfWeek.getTime()
                    window.calendarEvents.trello.push
                        id: card.url
                        title: "#{card.name}#{metadata.membersString}"
                        url: card.url
                        start: dueDate
                        end: dueDate
                        class: cls
                else
                    if prevBoardName != boardName
                        $("<h5>").text("#{boardName}").appendTo($noDueDate)
                    link = $("<a>").attr({href: card.url, target: "trello"}).addClass("card #{cls}")
                    link.text("#{card.name}#{metadata.membersString}").appendTo($noDueDate)
                    prevBoardName = boardName



formatCardMetaData = (members) ->
    metadata = {}
    metadata.initials = (window.organizationMembers[m].initials for m in members)
    if metadata.initials.length != 0
        metadata.membersString = " [#{metadata.initials.join(', ')}]"
        metadata.avatarStyles = ("avatar-#{i}" for i in metadata.initials)
        metadata.avatarString = "#{metadata.avatarStyles.join(' ')}"
    else
        metadata.membersString = ""
        metadata.avatarString = ""
    return metadata

getCompletedCards = () ->
    now = new Date()
    $.each TRELLO_BOARDS, (idx, boardId) ->
        Trello.get "boards/#{boardId}/cards?filter=closed&limit=100", (cards) ->
            for card in cards
                cardClosedDate = new Date(card.dateLastActivity)
                daysAgoClosed = (now-cardClosedDate)/1000/3600/24
                if daysAgoClosed <= 7.0
                    calendarCards.create
                        id: card.url
                        title: card.name
                        members: card.userIds
                        listId: card.idList
                        url: card.url
                        start: new Date(card.due).getTime()
                        end: new Date(card.due).getTime()
                        complete: true

loadInitialData = (callback) ->
    Trello.members.get "me", (member) ->
        $("#fullName").text(member.fullName)

        # Output a list of all of the cards that the member
        # is assigned to
        Trello.get "organizations/arachnys1/members?fields=all", (members) ->
            for member in members
                users.create
                    id: member.id
                    initials: member.initials
                    avatarHash: member.avatarHash
                #setAvatarStyle member.initials, member.avatarHash
            for boardId in TRELLO_BOARDS
                Trello.get "boards/#{boardId}/lists", (lists) ->
                    for list in lists
                        lists.create
                            id: list.id
                            name: list.name
            callback()

setAvatarStyle = (initials, avatarHash) ->
    # Create a style .avatar-INITIALS for displaying avatars
    imageUrl = "https://trello-avatars.s3.amazonaws.com/#{avatarHash}/30.png"
    $("<style type='text/css'>.avatar-#{initials} { background-image: url('#{imageUrl}'); background-repeat: no-repeat; background-position-x:right; } </style>").appendTo('head')


window.updateLoggedIn = () ->
    isLoggedIn = Trello.authorized()
    $("#loggedout").toggle(!isLoggedIn)
    $("#loggedin").toggle(isLoggedIn)

window.logout = () ->
    Trello.deauthorize()
    updateLoggedIn()

window.getFeed = () ->
    service = new google.gdata.calendar.CalendarService('arachnys')
    service.getEventsFeed(FEED_URL, handleFeed, handleError)

getHash = (str) ->
    hash = 0
    if str.length == 0
        return 0
    for char in str
        code = char.charCodeAt(0)
        hash = ((hash<<5)-hash)+code
        hash |= 0
    return hash

handleFeed = (feed) ->
    entries = feed.entry
    for entry in entries
        calendarCards.create
            id: getHash(entry.id.$t)
            title: "#{entry.title.$t} on tech duty"
            url: entry.link[0].href
            start: new Date(entry['gd$when'][0]['startTime']).getTime()
            end: new Date(entry['gd$when'][0]['endTime']).getTime()
            class: "event-warning #{metadata.avatarString} event-large"

        initials = NAME_TO_INITIALS_MAPPING[entry.title.$t.toLowerCase()]
        if (not initials) or (not organizationMembersInitials[initials]?)
            console.error "No initials for", entry.title.$t
            return
        member = organizationMembersInitials[initials]
        metadata = formatCardMetaData([member.id])
        window.calendarEvents.gcal.push
            id: getHash(entry.id.$t)
            title: "#{entry.title.$t} on tech duty"
            url: entry.link[0].href
            start: new Date(entry['gd$when'][0]['startTime']).getTime()
            end: new Date(entry['gd$when'][0]['endTime']).getTime()
            class: "event-warning #{metadata.avatarString} event-large"
    updateCalendar()

updateCalendar = (events) ->
    flat = []
    for source, events of window.calendarEvents
        for item in events
            flat.push item
    window.calendar.setOptions
        events_source: flat
    window.calendar2.setOptions
        events_source: flat
    window.calendar.view()
    window.calendar2.view()

updateGcal = () ->
    feedUrl = JSON.parse(localStorage.getItem(GCAL_FEED_URL_LS_KEY))
    if not feedUrl
        url = window.prompt('Enter Google Calendar feed URL for tech rota (should end with /full)')
        localStorage.setItem(GCAL_FEED_URL_LS_KEY, JSON.stringify(url))
        feedUrl = JSON.parse(localStorage.getItem(GCAL_FEED_URL_LS_KEY))
    if feedUrl
        $.getJSON "#{feedUrl}?alt=json-in-script&callback=?", (data) ->
            handleFeed data.feed
            # Poll for changes
            setTimeout(updateGcal, REFRESH_INTERVAL)
    else
        window.alert('Not possible to load Google Calendar data')

updatePipedrive = () ->
    apiKey = JSON.parse(localStorage.getItem(PIPEDRIVE_API_KEY_LS_KEY))
    if not apiKey
        key = window.prompt('Enter Pipedrive API key')
        localStorage.setItem(PIPEDRIVE_API_KEY_LS_KEY, JSON.stringify(key))
        apiKey = JSON.parse(localStorage.getItem(PIPEDRIVE_API_KEY_LS_KEY))
    if apiKey
        setTimeout(updatePipedrive, REFRESH_INTERVAL)
        getPipedriveActivities(apiKey)
    else
        window.alert('Not possible to load Pipedrive data')

getPipedriveActivities = (apiKey) ->
    window.calendarEvents.pipedrive = []
    $.getJSON "#{PIPEDRIVE_API_BASE}/users?api_token=#{apiKey}", (data) ->
        users = data.data
        userHash = {}
        for u in users
            userHash[u.id] = u
        for user in users
            $.getJSON "#{PIPEDRIVE_API_BASE}/activities/?done=0&api_token=#{apiKey}&user_id=#{user.id}", (activityData) ->
                if not activityData.data?
                    return
                for activity in activityData.data
                    date = new Date(activity.due_date).getTime()
                    user = userHash[activity.user_id]
                    initials = NAME_TO_INITIALS_MAPPING[user.name]
                    if (not initials) or (not organizationMembersInitials[initials]?)
                        console.error "No initials for", user
                        return
                    member = organizationMembersInitials[initials]
                    metadata = formatCardMetaData([member.id])
                    window.calendarEvents.pipedrive.push
                        id: activity.id
                        title: "#{activity.subject} #{metadata.membersString}"
                        url: "https://app.pipedrive.com/org/details/#{activity.org_id}"
                        start: date
                        end: date
                        class: "event-warning #{metadata.avatarString} event-large"
                updateCalendar()

window.getEventLine = (eventHash, idx) ->
    ret = {}
    hasItem = false
    for k, v of eventHash
        if idx < v.length
            hasItem = true
            ret[k] = v[idx]
        else
            ret[k] = null
    if hasItem
        return ret
    else
        return {}

refreshPage = () ->
    # So we always have most up-to-date code
    window.location.href = window.location.href

$ ->
    window.calendar = $('#calendar').calendar
        first_day: 1
        show_weekends: 0
        events_source: []
    window.calendar2 = $('#calendar2').calendar
        first_day: 1
        show_weekends: 0
        events_source: []
    window.calendar.view('week')
    window.calendar2.view('week')
    # About as inelegant as it gets
    window.calendar2.navigate('next')
    # racy
    setTimeout(updateGcal, 1000)
    setTimeout(refreshPage, 1000*60*60*AUTOREFRESH_HOURS)
    # Disable until we can work out layout
    #updatePipedrive()

