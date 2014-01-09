
window.onAuthorize = () ->
    updateLoggedIn()
    $("#output").empty()

    Trello.members.get "me", (member) ->
        $("#fullName").text(member.fullName)

        $cards = $("<div>").text("Loading Cards...").appendTo("#calendar");
        $noDueDate = $('<div>').appendTo('#no-due-date')
        # Output a list of all of the cards that the member
        # is assigned to
        Trello.get "boards/UsP5zlas/cards", (cards) ->
            $noDueDate.empty()
            $('<h3>No due date</h3>').appendTo($noDueDate)
            window.calendarEvents.trello = []
            $.each cards, (ix, card) ->
                if card.due
                    window.calendarEvents.trello.push
                        id: card.url
                        title: card.name
                        url: card.url
                        start: new Date(card.due).getTime()
                        end: new Date(card.due).getTime()
                        class: 'event-important'
                else
                    link = $("<a>").attr({href: card.url, target: "trello"}).addClass("card")
                    link.text(card.name).appendTo($noDueDate)
            updateCalendar()

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

window.calendarEvents = {}

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
            title: entry.title.$t
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
    console.debug flat
    window.calendar.setOptions
        events_source: flat
    window.calendar.view()


handleError = (error) ->
    console.debug error

$ ->
    window.calendar = $('#calendar').calendar
        first_day: 1
        events_source: []
    window.calendar.view('week')
    feedUrl = JSON.parse(localStorage.getItem('arachnysDashboardFeedUrl'))
    if not feedUrl
        url = window.prompt('Please enter your Google Calendar feed URL')
        localStorage.setItem('arachnysDashboardFeedUrl', JSON.stringify(url))
        feedUrl = JSON.parse(localStorage.getItem('arachnysDashboardFeedUrl'))
    if feedUrl
        $.getJSON "#{feedUrl}?alt=json-in-script&callback=?", (data) ->
            handleFeed data.feed
    else
        window.alert('Not possible to load Google Calendar data')

