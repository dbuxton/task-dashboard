
BOARD_ID = 'UsP5zlas'

window.calendarEvents = {}

window.organizationMembers = {}

window.boardLists = {}

window.onAuthorize = () ->
    updateLoggedIn()
    $("#output").empty()

    loadInitialData(getBoardCards)

getBoardCards = (callback) ->
    $noDueDate = $('<div>').text('Loading...').appendTo('#no-due-date')
    Trello.get "boards/#{BOARD_ID}/cards", (cards) ->
        $noDueDate.empty()
        $('<h3>No due date</h3>').appendTo($noDueDate)
        window.calendarEvents.trello = []
        prevBoardName = null
        $.each cards, (ix, card) ->
            initials = (window.organizationMembers[m].initials for m in card.idMembers)
            if initials.length != 0
                membersString = " [#{initials.join(', ')}]"
            else
                membersString = ""
            boardName = window.boardLists[card.idList].name
            if boardName == 'Complete'
                cls = 'event-success event-fade'
            else if boardName == 'In progress'
                cls = 'event-warning'
            else
                cls = 'event-important'
            if card.due
                window.calendarEvents.trello.push
                    id: card.url
                    title: "#{card.name}#{membersString}"
                    url: card.url
                    start: new Date(card.due).getTime()
                    end: new Date(card.due).getTime()
                    class: cls
            else
                if prevBoardName != boardName
                    $("<h4>").text("#{boardName}").appendTo($noDueDate)
                link = $("<a>").attr({href: card.url, target: "trello"}).addClass("card")
                link.text("#{card.name}#{membersString}").appendTo($noDueDate)
                prevBoardName = boardName
        updateCalendar()

loadInitialData = (callback) ->
    Trello.members.get "me", (member) ->
        $("#fullName").text(member.fullName)

        # Output a list of all of the cards that the member
        # is assigned to
        Trello.get "organizations/arachnys1/members?fields=all", (members) ->
            for member in members
                window.organizationMembers[member.id] = member
            Trello.get "boards/#{BOARD_ID}/lists", (lists) ->
                for list in lists
                    window.boardLists[list.id] = list
                callback()

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
    window.calendarEvents.gcal = []
    entries = feed.entry
    for entry in entries
        window.calendarEvents.gcal.push
            id: getHash(entry.id.$t)
            title: "#{entry.title.$t} on tech duty"
            url: entry.link[0].href
            start: new Date(entry['gd$when'][0]['startTime']).getTime()
            end: new Date(entry['gd$when'][0]['endTime']).getTime()
            class: 'event-info'
    updateCalendar()

updateCalendar = (events) ->
    flat = []
    for source, events of window.calendarEvents
        for item in events
            item.id = i
            flat.push item
    window.calendar.setOptions
        events_source: flat
    window.calendar2.setOptions
        events_source: flat
    window.calendar.view()
    window.calendar2.view()


handleError = (error) ->
    console.debug error

$ ->
    window.calendar = $('#calendar').calendar
        first_day: 1
        events_source: []
    window.calendar2 = $('#calendar2').calendar
        first_day: 1
        events_source: []
    window.calendar.view('week')
    window.calendar2.view('week')
    # About as inelegant as it gets
    window.calendar2.navigate('next')
    feedUrl = JSON.parse(localStorage.getItem('arachnysDashboardFeedUrl'))
    if not feedUrl
        url = window.prompt('Enter Google Calendar feed URL for tech rota (should end with /full)')
        localStorage.setItem('arachnysDashboardFeedUrl', JSON.stringify(url))
        feedUrl = JSON.parse(localStorage.getItem('arachnysDashboardFeedUrl'))
    if feedUrl
        $.getJSON "#{feedUrl}?alt=json-in-script&callback=?", (data) ->
            handleFeed data.feed
    else
        window.alert('Not possible to load Google Calendar data')

