
BOARD_ID = 'UsP5zlas'
REFRESH_INTERVAL = 60000
GCAL_FEED_URL_LS_KEY = 'arachnysDashboardFeedUrl'
PIPEDRIVE_API_KEY_LS_KEY = 'arachnysPipedriveApiKey'
PIPEDRIVE_API_BASE = 'https://api.pipedrive.com/v1'

window.calendarEvents = {}

window.organizationMembers = {}

window.boardLists = {}

window.onAuthorize = () ->
    updateLoggedIn()
    $("#output").empty()
    loadInitialData(getBoardCards)

getBoardCards = (callback) ->
    getCompletedCards()
    $noDueDate = $('#no-due-date')
    $('<div>').text('Loading...').appendTo($noDueDate)
    Trello.get "boards/#{BOARD_ID}/cards?filter=visible", (cards) ->
        $noDueDate.empty()
        $('<h3>No due date</h3>').appendTo($noDueDate)
        window.calendarEvents.trello = []
        prevBoardName = null
        $.each cards, (ix, card) ->
            metadata = formatCardMetaData(card.idMembers)
            boardName = window.boardLists[card.idList].name
            if boardName == "Complete"
                cls = "event-success event-fade #{metadata.avatarString} #{if metadata.avatarString != '' then 'event-large'}"
            else if boardName == "In progress"
                cls = "event-warning #{metadata.avatarString} #{if metadata.avatarString != '' then 'event-large'}"
            else
                cls = "event-important #{metadata.avatarString} #{if metadata.avatarString != '' then 'event-large'}"
            if card.due
                window.calendarEvents.trello.push
                    id: card.url
                    title: "#{card.name}#{metadata.membersString}"
                    url: card.url
                    start: new Date(card.due).getTime()
                    end: new Date(card.due).getTime()
                    class: cls
            else
                if prevBoardName != boardName
                    $("<h4>").text("#{boardName}").appendTo($noDueDate)
                link = $("<a>").attr({href: card.url, target: "trello"}).addClass("card #{metadata.avatarString} #{if metadata.avatarString != '' then 'event-large'}")
                link.text("#{card.name}#{metadata.membersString}").appendTo($noDueDate)
                prevBoardName = boardName
        updateCalendar()
        setTimeout(getBoardCards, REFRESH_INTERVAL)

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
    Trello.get "boards/#{BOARD_ID}/cards?filter=closed&limit=100", (cards) ->
        closedCards = []
        now = new Date()
        for card in cards
            cardClosedDate = new Date(card.dateLastActivity)
            daysAgoClosed = (now-cardClosedDate)/1000/3600/24
            if daysAgoClosed <= 14.0
                closedCards.push card
        $complete = $('#completed-cards').empty()
        $("<h3>Completed/archived cards in last 14 days: #{closedCards.length}</h3>").appendTo($complete)
        count = 0
        for card in closedCards
            metadata = formatCardMetaData(card.idMembers)
            if count % 4 == 0
                $row = $("<div class='row'></div>").appendTo($complete)
            $("<div class='col-md-3 card'><div class='card-inner #{metadata.avatarString}'><i class='fa fa-trello'></i> <a href='#{card.url}'>#{card.name}#{metadata.membersString}</a></div></div>").appendTo($row)
            count++

loadInitialData = (callback) ->
    Trello.members.get "me", (member) ->
        $("#fullName").text(member.fullName)

        # Output a list of all of the cards that the member
        # is assigned to
        Trello.get "organizations/arachnys1/members?fields=all", (members) ->
            for member in members
                window.organizationMembers[member.id] = member
                setAvatarStyle member.initials, member.avatarHash

            Trello.get "boards/#{BOARD_ID}/lists", (lists) ->
                for list in lists
                    window.boardLists[list.id] = list
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
                for activity in activityData.data
                    date = new Date(activity.due_date).getTime()
                    user = userHash[activity.user_id]
                    console.debug user, userHash
                    window.calendarEvents.pipedrive.push
                        id: activity.id
                        title: "#{activity.subject} [#{user.name}]"
                        url: "https://app.pipedrive.com/org/details/#{activity.org_id}"
                        start: date
                        end: date
                        class: 'event-warning'
                updateCalendar()


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
    updateGcal()
    # Disable until we can work out layout
    #updatePipedrive()

