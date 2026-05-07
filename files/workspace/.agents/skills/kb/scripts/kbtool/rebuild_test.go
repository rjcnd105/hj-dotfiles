package main

import "testing"

func TestParseFrontmatterPublish(t *testing.T) {
	p := &Page{}

	parseFrontmatter(p, []string{"publish: false"})

	if !p.publishPresent {
		t.Fatal("expected publish frontmatter to be recorded as present")
	}
	if p.Publish {
		t.Fatal("expected publish false to parse as false")
	}
}

func TestPublicIndexPagesSkipsExplicitPublishFalse(t *testing.T) {
	published := &Page{Name: "published", Publish: true, publishPresent: true}
	implicit := &Page{Name: "implicit"}
	private := &Page{Name: "private", Publish: false, publishPresent: true}

	got := publicIndexPages([]*Page{published, implicit, private})

	if len(got) != 2 {
		t.Fatalf("expected 2 public pages, got %d", len(got))
	}
	if got[0] != published || got[1] != implicit {
		t.Fatalf("unexpected public pages: %#v", got)
	}
}
