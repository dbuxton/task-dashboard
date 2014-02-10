
TRELLO_BOARDS = ['UsP5zlas', 'cZd9apE5', 'zkkCd4kN', 'ljHglwed']
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

# Models
List = Backbone.Model.extend
    defaults:
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
        name: "No name"
        url: "#"
        start: null
        end: null
        listId: null
        archived: false
        complete: true
        inPast: false
        userIds: []
        initials: []
        # 'pipedrive', 'gcal', etc
        source: "trello"
        dueInPreviousWeek: false
        avatarClasses: ''
        statusClasses: ''
        classString: ''


    initialize: () ->
        @_inPast()
        @calculateAttributes()
        # Listen for updates
        @bind('change:start', '_inPast')
        @bind('change', '@calculateAttributes')

    _inPast: () ->
        if not this.get('start')
            @set('inPast', false)
            return
        now = new Date()
        startDate = new Date(this.get('start'))
        @set('inPast', (now.getTime() - startDate.getTime()) > 0)

    calculateAttributes: () ->
        classString = "card event-large"
        userIds = @get('userIds')
        now = new Date()
        firstOfWeek = getMonday(now).getTime()
        initials = []
        if @get('start') == 0
            @set('start', null)
        if userIds? and userIds.length > 0
            for userId in userIds
                user = trelloUsers.get userId
                initials.push user.get('initials')
            avatarStyles = ("avatar-#{i}" for i in initials)
            @set('initials', initials.join(', '))
            @set('avatarClasses', avatarStyles.join(' '))
            @set("title", "#{@get('name')} [#{@get('initials')}]")
        if @get('source') == 'gcal'
            classString = "#{classString} event-gcal"
        if @get('source') == 'trello'
            if @get('inPast')
                @set('statusClasses', "event-in-past")
            list = trelloLists.get(@get('listId'))
            if list.get('name') == "Complete"
                @set('complete', true)
                @set('statusClasses', "#{@get('statusClasses')} event-fade event-success")
            else if list.get('name') == "In progress"
                @set('statusClasses', "#{@get('statusClasses')} event-progress")
            else
                @set('statusClasses', "#{@get('statusClasses')} event-not-started")
            if @get('start')?
                due = new Date(@get('start')).getTime()
                if due < firstOfWeek
                    @set('dueInPreviousWeek', true)
        @set 'class', "#{classString} #{@get('statusClasses')} #{@get('avatarClasses')}"

    viewEvent: () ->
        window.location.href = url

# Collections
Cards = Backbone.Collection.extend
    localStorage: new Backbone.LocalStorage("Cards")
    model: Card

Users = Backbone.Collection.extend
    localStorage: new Backbone.LocalStorage("Users")
    model: User

Lists = Backbone.Collection.extend
    localStorage: new Backbone.LocalStorage("Lists")
    model: List

trelloUsers = new Users

trelloLists = new Lists

calendarCards = new Cards

CardView = Backbone.View.extend

    template: _.template """
    <div class="card-inner <%= avatarClasses %>">
        <i class='fa fa-trello'></i>
        <%= name %><% if (initials.length > 0) { %> [<%= initials %>] <% } %>
    </div>
    """

    initialize: () ->
        @listenTo(@model, 'change', @render)

    render: () ->
        @$el.html(@template(@model.toJSON()))
        return @

    events: () ->
        "click": "openCard"

    openCard: () ->
        window.open(@model.get('url'), '_blank')

CompletedCardView = CardView.extend

    className: () ->
        return "col-md-3 card"

UnscheduledCardView = CardView.extend

    template: _.template """
        <%= name %><% if (initials.length > 0) { %> [<%= initials %>] <% } %>
    """

    className: () ->
        return "card #{@model.get('avatarClasses')} #{@model.get('statusClasses')} event-large"

# We don't need a view for calendar as that's handled by lib
# We do for other things though

CardsView = Backbone.View.extend

    initialize: () ->
        @listenTo(calendarCards, 'add', @addOne)
        @listenTo(calendarCards, 'reset', @addAll)

    addAll: () ->
        unscheduled = new Cards(calendarCards)
        unscheduled.each(@addOne, @)



CompletedCardsView = CardsView.extend

    el: '#completed-cards'

    cardView: CompletedCardView

    addOne: (card) ->
        if card.get('archived') == true
            view = new @cardView
                model: card
            @$el.append(view.render().el)

UnscheduledCardsView = CardsView.extend

    el: '#no-due-date'

    cardView: UnscheduledCardView

    addOne: (card) ->
        unless card.get('source') == 'trello'
            return
        if card.get('archived') == false and card.get('start') == null
            if card.get('complete') == true
                return
            view = new @cardView
                model: card
            @$el.append(view.render().el)

OverdueCardsView = UnscheduledCardsView.extend

    el: '#overdue'

    addOne: (card) ->
        unless card.get('source') == 'trello'
            return
        if card.get('archived') == false and card.get('dueInPreviousWeek') == true
            if card.get('complete') == true
                return
            view = new @cardView
                model: card
            @$el.append(view.render().el)

CustomerRequestsView = CompletedCardsView.extend

    el: '#customer-requests'

    addOne: (card) ->
        if card.get('name').toLowerCase().indexOf('[customer request]') != -1
            if card.get('complete') == true or card.get('archived') == true
                return
            view = new @cardView
                model: card
            @$el.append(view.render().el)


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
    setTimeout(refreshPage, 1000*60*60*AUTOREFRESH_HOURS)

    completedCards = new CompletedCardsView()
    unscheduledCards = new UnscheduledCardsView()
    overdueCards = new OverdueCardsView()
    customerRequestsView = new CustomerRequestsView()

    # Disable until we can work out layout
    #updatePipedrive()

window.onAuthorize = () ->
    updateLoggedIn()
    $("#output").empty()
    loadInitialData().done () ->
        getBoardCards()
        updateGcal()

getMonday = (d) ->
    d = new Date(d)
    day = d.getDay()
    diff = d.getDate() - day + (day == 0 ? -6:1)
    return new Date(d.setDate(diff))

getBoardCards = () ->
    now = new Date()
    firstOfWeek = getMonday(now)
    $.each TRELLO_BOARDS, (idx, boardId) ->
        Trello.get "boards/#{boardId}/cards?filter=visible", (cards) ->
            for card in cards
                calendarCards.create
                    id: card.url
                    name: card.name
                    userIds: card.idMembers
                    listId: card.idList
                    url: card.url
                    start: new Date(card.due).getTime()
                    end: new Date(card.due).getTime()
                    complete: false
            updateCalendar()

    $.each TRELLO_BOARDS, (idx, boardId) ->
        Trello.get "boards/#{boardId}/cards?filter=closed&limit=100", (cards) ->
            for card in cards
                cardClosedDate = new Date(card.dateLastActivity)
                daysAgoClosed = (now-cardClosedDate)/1000/3600/24
                if daysAgoClosed <= 7.0
                    calendarCards.create
                        id: card.url
                        name: card.name
                        userIds: card.idMembers
                        listId: card.idList
                        url: card.url
                        start: new Date(card.due).getTime()
                        end: new Date(card.due).getTime()
                        archived: true
            updateCalendar()

setAvatarStyle = (initials, avatarHash) ->
    # Create a style .avatar-INITIALS for displaying avatars
    imageUrl = "https://trello-avatars.s3.amazonaws.com/#{avatarHash}/30.png"
    $("<style type='text/css'>.avatar-#{initials} { background-image: url('#{imageUrl}'); background-repeat: no-repeat; background-position-x:right; } </style>").appendTo('head')

loadCurrentMember = () ->
    deferred = $.Deferred()
    Trello.members.get "me", (member) ->
        $("#fullName").text(member.fullName)
        deferred.resolve()
    return deferred.promise()

loadMembers = () ->
    deferred = $.Deferred()
    Trello.get "organizations/arachnys1/members?fields=all", (members) ->
        for member in members
            trelloUsers.create
                id: member.id
                name: member.fullName
                initials: member.initials
                avatarHash: member.avatarHash
            setAvatarStyle(member.initials, member.avatarHash)
        deferred.resolve()
    return deferred.promise()

loadBoardLists = (boardId) ->
    deferred = $.Deferred()
    Trello.get "boards/#{boardId}/lists", (lists) ->
        for list in lists
            trelloLists.create
                id: list.id
                name: list.name
        deferred.resolve()
    return deferred.promise()

loadBoards = () ->
    deferred = $.Deferred()
    $.when(TRELLO_BOARDS.map(loadBoardLists)).done () ->
        deferred.resolve()
    return deferred.promise()

loadInitialData = () ->
    deferred = $.Deferred()

    $.when(
        loadCurrentMember(),
        loadMembers(),
        loadBoards()
    ).done () ->
        deferred.resolve()
    return deferred.promise()

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
        initials = NAME_TO_INITIALS_MAPPING[entry.title.$t.toLowerCase()]
        if not initials
            console.error "No initials for", entry.title.$t.toLowerCase()
            return
        user = trelloUsers.findWhere({initials: initials})
        if not user?
            console.error "User with initials #{initials} not found"
            return
        calendarCards.create
            id: getHash(entry.id.$t)
            name: "#{entry.title.$t} on tech duty"
            url: entry.link[0].href
            start: new Date(entry['gd$when'][0]['startTime']).getTime()
            end: new Date(entry['gd$when'][0]['endTime']).getTime()
            userIds: [user.id]
            source: 'gcal'
    updateCalendar()

updateCalendar = () ->
    flat = []
    for item in calendarCards.where({archived: false})
        flat.push item.toJSON()
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


