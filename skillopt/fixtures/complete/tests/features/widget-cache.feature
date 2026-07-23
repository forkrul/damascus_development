Feature: Widget cache
  Scenario: Cached widget is returned before expiry
    Given a widget stored with a 60 second TTL
    When I fetch it 10 seconds later
    Then I receive the stored widget

  Scenario: Expired widget is not returned
    Given a widget stored with a 60 second TTL
    When I fetch it 61 seconds later
    Then I receive nothing
